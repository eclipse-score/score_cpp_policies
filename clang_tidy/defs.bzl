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

"""Public API for the S-CORE centralized clang-tidy policy.

Consumers load make_clang_tidy_aspect and make_clang_tidy_test from this file
instead of calling aspect_rules_lint directly. This guarantees:

  1. Modules without their own .clang-tidy are linted with the S-CORE baseline.
  2. SCORE-specific aspect defaults (lint_target_headers, angle_includes_are_system)
     are pre-wired without requiring each consumer to rediscover them.
  3. When aspect_rules_lint changes its API, only this file needs updating;
     all consumers get the fix automatically on the next score_cpp_policies bump.
"""

load("@aspect_rules_lint//lint:clang_tidy.bzl", "lint_clang_tidy_aspect")
load("@aspect_rules_lint//lint:lint_test.bzl", "lint_test")

_BASELINE_CONFIG = Label("@score_cpp_policies//clang_tidy:.clang-tidy")

def make_clang_tidy_aspect(
        binary,
        local_configs = None,
        lint_target_headers = True,
        angle_includes_are_system = True):
    """Creates a clang-tidy aspect pre-wired with the S-CORE baseline config.

    Without local_configs, the S-CORE baseline is passed to clang-tidy as its
    config file. clang-tidy only searches for .clang-tidy files in the
    directories above the linted file, which never contain the baseline in
    score_cpp_policies' external repository. So local_configs replace the
    baseline; start them from the baseline to keep its checks.

    Args:
        binary: Label of the clang-tidy binary. Typically
                Label("@llvm_toolchain//:clang-tidy").
        local_configs: Optional list of Labels for module-specific .clang-tidy
                       files, found by clang-tidy's search above each linted
                       file. They replace the S-CORE baseline.
        lint_target_headers: Whether to also analyze headers of each target.
                             Default True. Set False to reduce CI time on very
                             large build graphs.
        angle_includes_are_system: Whether <...> includes are treated as system
                                   headers (suppresses warnings from them).
                                   Default True.

    Returns:
        A configured clang-tidy lint aspect.
    """
    if local_configs:
        return lint_clang_tidy_aspect(
            binary = binary,
            configs = local_configs,
            lint_target_headers = lint_target_headers,
            angle_includes_are_system = angle_includes_are_system,
        )
    return lint_clang_tidy_aspect(
        binary = binary,
        global_config = [_BASELINE_CONFIG],
        lint_target_headers = lint_target_headers,
        angle_includes_are_system = angle_includes_are_system,
    )

# Re-exported for single-import convenience: consumers only need one load().
make_clang_tidy_test = lint_test
