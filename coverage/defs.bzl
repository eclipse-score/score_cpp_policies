# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

"""Public API for the S-CORE centralized coverage report generator.

Consumers instantiate `score_coverage_reporter` in their own BUILD file to
create the `--coverage_report_generator` target that Bazel will call after
running `bazel coverage`. The macro wires in:

  1. The S-CORE baseline filter regexes — applied first, on top of which
     consumer-specific exclusions (`extra_regex_files`) are appended.
  2. The consumer's MODULE.bazel — used at runtime to resolve the real
     workspace root for source path mapping in llvm-cov reports.
  3. The shared reporter binary `@score_cpp_policies//coverage:reporter`,
     which performs profdata merge + HTML/LCOV/text report generation.
  4. The consumer-supplied llvm-cov and llvm-profdata binaries — passed by
     label so the consumer can pick their own llvm_toolchain version and
     repository name.

Typical usage from a consumer BUILD file:

    load("@score_cpp_policies//coverage:defs.bzl", "score_coverage_reporter")

    score_coverage_reporter(
        name = "reporter_wrapper",
        llvm_cov = "@llvm_toolchain//:llvm-cov",
        llvm_profdata = "@llvm_toolchain//:llvm-profdata",
        extra_regex_files = ["coverage_filter_regexes.txt"],
        visibility = ["//visibility:public"],
    )

and from the consumer .bazelrc:

    coverage --coverage_report_generator=//tools/coverage:reporter_wrapper
"""


_BASELINE_REGEX = "@score_cpp_policies//coverage:filter_regexes.txt"
_REPORTER = "@score_cpp_policies//coverage:reporter"

# ---------------------------------------------------------------------------
# Instrumented sources collection.
#
# llvm-cov only reports files whose object files were linked into one of the
# tests it was asked to analyse. Source files that exist in the workspace but
# are not linked into any cc_test (directly or transitively) therefore never
# appear in the coverage report - even though they would normally be
# instrumented under --instrumentation_filter.
#
# To surface those files at 0% coverage we ship:
#
#   * _collect_sources_aspect - walks the dependency graph of a target,
#     gathers srcs (.cpp/.cc/.cxx/.c/.C) from every cc_library, cc_binary,
#     and cc_test it encounters, and aggregates them into
#     InstrumentedSourcesInfo.
#   * score_instrumented_sources_manifest - applies the aspect to a list of
#     consumer-supplied targets and writes a text file with one
#     workspace-relative source path per line.
#
# The consumer points score_coverage_reporter at this manifest via the
# optional `instrumented_sources_manifest` attribute. The reporter then
# augments the llvm-cov LCOV + HTML output with synthetic 0%-coverage entries
# for every manifest entry that did not appear in the report.
# ---------------------------------------------------------------------------

InstrumentedSourcesInfo = provider(
    doc = "Aggregate of all C/C++ source files reachable through cc_* targets.",
    fields = {
        "sources": "depset of File objects (workspace-local C/C++ source files)",
    },
)

_CC_SRC_EXTS = ("cc", "cpp", "cxx", "c", "C")
_CC_KINDS = ("cc_library", "cc_binary", "cc_test")
_PROPAGATE_ATTRS = ["deps", "srcs", "implementation_deps"]

def _collect_sources_aspect_impl(target, ctx):
    direct = []
    if ctx.rule.kind in _CC_KINDS:
        for src in getattr(ctx.rule.attr, "srcs", None) or []:
            for f in src.files.to_list():
                if f.extension in _CC_SRC_EXTS and not f.short_path.startswith("../"):
                    direct.append(f)

    transitive = []
    for attr_name in _PROPAGATE_ATTRS:
        for dep in getattr(ctx.rule.attr, attr_name, None) or []:
            if InstrumentedSourcesInfo in dep:
                transitive.append(dep[InstrumentedSourcesInfo].sources)

    return [InstrumentedSourcesInfo(
        sources = depset(direct = direct, transitive = transitive),
    )]

_collect_sources_aspect = aspect(
    implementation = _collect_sources_aspect_impl,
    attr_aspects = _PROPAGATE_ATTRS,
    provides = [InstrumentedSourcesInfo],
    doc = "Collect C/C++ source files from cc_* targets reachable via deps/srcs.",
)

def _instrumented_sources_manifest_impl(ctx):
    transitive = [
        t[InstrumentedSourcesInfo].sources
        for t in ctx.attr.targets
        if InstrumentedSourcesInfo in t
    ]
    files = depset(transitive = transitive).to_list()

    # Deduplicate (Starlark has no ordered set type) and sort for determinism.
    paths = sorted({f.short_path: None for f in files}.keys())

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    content = "\n".join(paths) + ("\n" if paths else "")
    ctx.actions.write(output = out, content = content)
    return [DefaultInfo(files = depset([out]))]

score_instrumented_sources_manifest = rule(
    implementation = _instrumented_sources_manifest_impl,
    attrs = {
        "targets": attr.label_list(
            aspects = [_collect_sources_aspect],
            mandatory = True,
            doc = "Targets whose transitive cc_* source files should be listed.",
        ),
    },
    doc = """Emit a text manifest of C/C++ source files reachable from `targets`.

The output is a newline-separated list of workspace-relative paths. Pass this
target to score_coverage_reporter(instrumented_sources_manifest = ...) so the
reporter can add 0%-coverage entries for files that no test linked against.""",
)

def _rlocation_path(ctx, file):
    """Return the Runfiles.Rlocation()-compatible path for a Bazel File.

    External-repo files have short_path = "../repo/path" — strip the "../".
    Main-workspace files have short_path = "pkg/file" — prepend workspace name.
    """
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return ctx.workspace_name + "/" + file.short_path

# Template for the thin wrapper script generated per consumer.
# Uses %s substitution so bash $-variables are never touched by Starlark.
_WRAPPER_TEMPLATE = """\
#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${RUNFILES_DIR:-}" || ! -d "${RUNFILES_DIR}" ]]; then
  RUNFILES_DIR="$(cd "$(dirname "$0")" && pwd)/$(basename "$0").runfiles"
fi
exec "${RUNFILES_DIR}/%s" \\
  --filter_regexes="%s" \\
  --module_bazel="%s" \\
  --llvm_cov="%s" \\
  --llvm_profdata="%s" \\
%s  "$@"
"""


def _score_coverage_reporter_impl(ctx):
    reporter_rloc = _rlocation_path(ctx, ctx.executable._reporter)
    filter_rloc = _rlocation_path(ctx, ctx.file.filter_regexes)
    module_bazel_rloc = _rlocation_path(ctx, ctx.file.module_bazel)
    llvm_cov_rloc = _rlocation_path(ctx, ctx.file.llvm_cov)
    llvm_profdata_rloc = _rlocation_path(ctx, ctx.file.llvm_profdata)

    manifest_line = ""
    if ctx.file.instrumented_sources_manifest:
        manifest_rloc = _rlocation_path(ctx, ctx.file.instrumented_sources_manifest)
        manifest_line = (
            "  --instrumented_sources_manifest=\"%s\" \\\n" % manifest_rloc
        )

    wrapper = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = wrapper,
        content = _WRAPPER_TEMPLATE % (
            reporter_rloc,
            filter_rloc,
            module_bazel_rloc,
            llvm_cov_rloc,
            llvm_profdata_rloc,
            manifest_line,
        ),
        is_executable = True,
    )

    runfiles_files = [
        ctx.file.filter_regexes,
        ctx.file.module_bazel,
        ctx.file.llvm_cov,
        ctx.file.llvm_profdata,
    ]
    if ctx.file.instrumented_sources_manifest:
        runfiles_files.append(ctx.file.instrumented_sources_manifest)

    runfiles = ctx.runfiles(files = runfiles_files).merge(
        ctx.attr._reporter[DefaultInfo].default_runfiles,
    )

    return [DefaultInfo(executable = wrapper, runfiles = runfiles)]


_score_coverage_reporter_rule = rule(
    implementation = _score_coverage_reporter_impl,
    executable = True,
    attrs = {
        "llvm_cov": attr.label(mandatory = True, allow_single_file = True),
        "llvm_profdata": attr.label(mandatory = True, allow_single_file = True),
        "filter_regexes": attr.label(mandatory = True, allow_single_file = True),
        "module_bazel": attr.label(mandatory = True, allow_single_file = True),
        "instrumented_sources_manifest": attr.label(
            allow_single_file = True,
            default = None,
        ),
        "_reporter": attr.label(
            default = Label(_REPORTER),
            executable = True,
            cfg = "exec",
        ),
    },
)


def score_coverage_reporter(
        name,
        llvm_cov,
        llvm_profdata,
        extra_regex_files = None,
        instrumented_sources_manifest = None,
        **kwargs):
    """Create a Bazel --coverage_report_generator wrapper for this repository.

    Args:
        name: The target name. Reference it as
              `--coverage_report_generator=//<pkg>:<name>` in your
              coverage.bazelrc.
        llvm_cov: Label of the llvm-cov binary (typically
                  "@llvm_toolchain//:llvm-cov").
        llvm_profdata: Label of the llvm-profdata binary (typically
                       "@llvm_toolchain//:llvm-profdata").
        extra_regex_files: Optional list of additional filter-regex file labels
                           (or strings) to concatenate AFTER the
                           @score_cpp_policies baseline. Use these to exclude
                           consumer-specific patterns (e.g. project-only
                           generator outputs).
        instrumented_sources_manifest: Optional label of a
                           `score_instrumented_sources_manifest` target. When
                           provided, the reporter adds 0%-coverage entries for
                           every file in the manifest that did not appear in
                           the llvm-cov report (i.e. files that no test linked
                           against).
        **kwargs: Forwarded to the underlying rule (e.g. visibility, tags).
    """
    extra_regex_files = extra_regex_files or []

    merged_name = name + "_merged_filter_regexes"
    merged_out = merged_name + ".txt"

    # Concatenate baseline regexes + consumer extras into a single file.
    native.genrule(
        name = merged_name,
        srcs = [_BASELINE_REGEX] + list(extra_regex_files),
        outs = [merged_out],
        cmd = "cat $(SRCS) > $@",
    )

    _score_coverage_reporter_rule(
        name = name,
        llvm_cov = llvm_cov,
        llvm_profdata = llvm_profdata,
        filter_regexes = ":" + merged_name,
        module_bazel = "//:MODULE.bazel",
        instrumented_sources_manifest = instrumented_sources_manifest,
        **kwargs
    )
