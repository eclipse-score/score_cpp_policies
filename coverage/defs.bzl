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
_MERGER = "@score_cpp_policies//coverage:merger"

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
    sources = depset(transitive = transitive)
    files = sources.to_list()

    # Deduplicate (Starlark has no ordered set type) and sort for determinism.
    paths = sorted({f.short_path: None for f in files}.keys())

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    content = "\n".join(paths) + ("\n" if paths else "")
    ctx.actions.write(output = out, content = content)

    # The manifest text file only lists paths - the reporter also needs the
    # actual source files present on disk (as runfiles) so it can read them
    # under sandboxing. Expose them via default_runfiles so consumers that
    # depend on this target (e.g. score_coverage_reporter) can merge them in.
    return [
        DefaultInfo(
            files = depset([out]),
            runfiles = ctx.runfiles(transitive_files = sources),
        ),
        InstrumentedSourcesInfo(sources = sources),
    ]

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

    # Merge in the actual instrumented source files (not just the manifest
    # .txt listing their paths) so the reporter can find them on disk when
    # the coverage-report-generator action runs sandboxed. Without this,
    # _find_untested_sources() silently drops every manifest entry because
    # the workspace-relative path does not resolve to an existing file.
    if ctx.attr.instrumented_sources_manifest:
        runfiles = runfiles.merge(
            ctx.attr.instrumented_sources_manifest[DefaultInfo].default_runfiles,
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

# ---------------------------------------------------------------------------
# Per-test coverage merger wrapper.
#
# :merger falls back to the ambient LLVM_PROFDATA environment variable when
# no --llvm_profdata rlocation arg is given, but nothing in this repo (or a
# typical consumer setup) actually sets that variable - it silently breaks
# outside of an environment that happens to export it. score_coverage_merger
# generates a thin wrapper (the same pattern as score_coverage_reporter) that
# supplies llvm-profdata by label instead, so the merger step is hermetic.
# ---------------------------------------------------------------------------

_MERGER_WRAPPER_TEMPLATE = """\
#!/usr/bin/env bash
set -euo pipefail
# Bazel invokes --coverage_output_generator as a tool from inside another
# action (the per-test coverage-collection action), which already has its
# OWN RUNFILES_DIR set in the environment (pointing at the *test's* runfiles,
# not this wrapper's). Trusting an inherited RUNFILES_DIR here would resolve
# paths against the wrong tree, so always prefer this script's own sibling
# runfiles directory and only fall back to the ambient value if that
# self-derived directory doesn't exist.
SELF_RUNFILES_DIR="$(cd "$(dirname "$0")" && pwd)/$(basename "$0").runfiles"
if [[ -d "${SELF_RUNFILES_DIR}" ]]; then
  RUNFILES_DIR="${SELF_RUNFILES_DIR}"
elif [[ -z "${RUNFILES_DIR:-}" || ! -d "${RUNFILES_DIR}" ]]; then
  echo "ERROR: could not locate merger_wrapper's runfiles directory" >&2
  exit 1
fi
exec "${RUNFILES_DIR}/%s" \\
  --llvm_profdata="${RUNFILES_DIR}/%s" \\
  "$@"
"""

def _score_coverage_merger_impl(ctx):
    merger_rloc = _rlocation_path(ctx, ctx.executable._merger)
    llvm_profdata_rloc = _rlocation_path(ctx, ctx.file.llvm_profdata)

    wrapper = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = wrapper,
        content = _MERGER_WRAPPER_TEMPLATE % (merger_rloc, llvm_profdata_rloc),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [ctx.file.llvm_profdata]).merge(
        ctx.attr._merger[DefaultInfo].default_runfiles,
    )

    return [DefaultInfo(executable = wrapper, runfiles = runfiles)]

_score_coverage_merger_rule = rule(
    implementation = _score_coverage_merger_impl,
    executable = True,
    attrs = {
        "llvm_profdata": attr.label(mandatory = True, allow_single_file = True),
        "_merger": attr.label(
            default = Label(_MERGER),
            executable = True,
            cfg = "exec",
        ),
    },
)

def score_coverage_merger(name, llvm_profdata, **kwargs):
    """Create a Bazel --coverage_output_generator wrapper for this repository.

    Wires llvm-profdata into the per-test merger step by label instead of
    relying on the ambient LLVM_PROFDATA environment variable, which nothing
    sets by default. Reference it from your coverage.bazelrc:

        coverage --coverage_output_generator=//tools/coverage:merger_wrapper

    Args:
        name: The target name.
        llvm_profdata: Label of the llvm-profdata binary (typically
                       "@llvm_toolchain//:llvm-profdata").
        **kwargs: Forwarded to the underlying rule (e.g. visibility, tags).
    """
    _score_coverage_merger_rule(
        name = name,
        llvm_profdata = llvm_profdata,
        **kwargs
    )
