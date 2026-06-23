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

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

_BASELINE_REGEX = "@score_cpp_policies//coverage:filter_regexes.txt"
_REPORTER = "@score_cpp_policies//coverage:reporter"

def score_coverage_reporter(
        name,
        llvm_cov,
        llvm_profdata,
        extra_regex_files = None,
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
        **kwargs: Forwarded to the underlying sh_binary (e.g. visibility, tags).
    """
    extra_regex_files = extra_regex_files or []

    merged_name = name + "_merged_filter_regexes"
    merged_out = merged_name + ".txt"
    wrapper_gen_name = name + "_wrapper_gen"
    wrapper_out = name + ".sh"

    # Concatenate baseline regexes + consumer extras into a single file.
    # Order is irrelevant for llvm-cov; it treats them as a set.
    native.genrule(
        name = merged_name,
        srcs = [_BASELINE_REGEX] + list(extra_regex_files),
        outs = [merged_out],
        cmd = "cat $(SRCS) > $@",
    )

    # Generate the wrapper shell script. It computes the consumer workspace
    # root from the runfiles location of //:MODULE.bazel and then execs the
    # shared reporter binary with the merged regex file, workspace root, and
    # consumer-supplied llvm tool rlocation paths.
    #
    # Escaping note: this genrule uses an unquoted heredoc (`<< EOF`) so the
    # shell would normally expand $... — we escape each `$` we want literal
    # in the output script as `\\$$`:
    #   * `$$` is Bazel's escape for a literal `$`.
    #   * `\` then makes the heredoc treat that `$` as literal.
    # `$(rlocationpath ...)` IS a Bazel make-variable and is intentionally
    # expanded at genrule time so the actual rlocation path is baked into
    # the script.
    native.genrule(
        name = wrapper_gen_name,
        srcs = [
            ":" + merged_name,
            "//:MODULE.bazel",
            llvm_cov,
            llvm_profdata,
        ],
        outs = [wrapper_out],
        tools = [_REPORTER],
        cmd = ("""cat > $@ << EOF
#!/usr/bin/env bash
set -euo pipefail
_SELF_DIR="\\$$(cd "\\$$(dirname "\\$$0")" && pwd)"
_SELF_NAME="\\$$(basename "\\$$0")"
if [[ -z "\\$${RUNFILES_DIR:-}" || ! -d "\\$${RUNFILES_DIR}" ]]; then
  if [[ -d "\\$${_SELF_DIR}/\\$${_SELF_NAME}.runfiles" ]]; then
    export RUNFILES_DIR="\\$${_SELF_DIR}/\\$${_SELF_NAME}.runfiles"
  fi
fi
WORKSPACE_ROOT="\\$$(cd "\\$$(dirname "\\$$(readlink -f "\\$${RUNFILES_DIR}/$(rlocationpath //:MODULE.bazel)")")" && pwd)/"
exec "\\$${RUNFILES_DIR}/$(rlocationpath %s)" \\\\
  --filter_regexes="$(rlocationpath :%s)" \\\\
  --workspace_root="\\$${WORKSPACE_ROOT}" \\\\
  --llvm_cov="$(rlocationpath %s)" \\\\
  --llvm_profdata="$(rlocationpath %s)" \\\\
  "\\$$@"
EOF
chmod +x $@
""" % (_REPORTER, merged_name, llvm_cov, llvm_profdata)),
    )

    sh_binary(
        name = name,
        srcs = [":" + wrapper_gen_name],
        data = [
            ":" + merged_name,
            _REPORTER,
            "//:MODULE.bazel",
            llvm_cov,
            llvm_profdata,
        ],
        **kwargs
    )
