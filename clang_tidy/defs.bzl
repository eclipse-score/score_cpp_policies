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

"""Clang-tidy support macros for S-CORE C++ modules.

Provides macros to create a clang-tidy aspect and test rule with S-CORE defaults.
Consuming projects call make_clang_tidy_aspect() in their own linters.bzl to
create a project-specific aspect bound to their toolchain and .clang-tidy config.

Example usage in your project's tools/lint/linters.bzl:

    load("@score_cpp_policies//clang_tidy:defs.bzl", "make_clang_tidy_aspect", "make_clang_tidy_test")

    clang_tidy_aspect = make_clang_tidy_aspect(
        binary = Label("@llvm_toolchain//:clang-tidy"),
        configs = [Label("//:.clang-tidy")],
    )

    clang_tidy_test = make_clang_tidy_test(aspect = clang_tidy_aspect)
"""

load("@aspect_rules_lint//lint:clang_tidy.bzl", "lint_clang_tidy_aspect")
load("@aspect_rules_lint//lint:lint_test.bzl", "lint_test")

def make_clang_tidy_aspect(
        binary,
        configs,
        lint_target_headers = True,
        angle_includes_are_system = True,
        verbose = False):
    """Creates a clang-tidy lint aspect with S-CORE defaults.

    Args:
        binary: Label of the clang-tidy binary.
                Must be resolved in the calling .bzl file's repository context,
                e.g. Label("@llvm_toolchain//:clang-tidy").
        configs: List of Labels to .clang-tidy config files that clang-tidy needs
                 as inputs, e.g. [Label("//:.clang-tidy")].
        lint_target_headers: Whether to lint headers owned by analyzed targets (default: True).
        angle_includes_are_system: Treat angle bracket includes as system headers (default: True).
        verbose: Enable verbose clang-tidy output (default: False).

    Returns:
        A clang-tidy aspect. Assign to a top-level variable in your .bzl file
        so it can be referenced via --aspects= in .bazelrc.
    """
    return lint_clang_tidy_aspect(
        binary = binary,
        configs = configs,
        lint_target_headers = lint_target_headers,
        angle_includes_are_system = angle_includes_are_system,
        verbose = verbose,
    )

def make_clang_tidy_test(aspect):
    """Creates a clang-tidy lint test rule for per-target testing.

    Args:
        aspect: The clang-tidy aspect returned by make_clang_tidy_aspect().

    Returns:
        A rule that can be instantiated in BUILD files to run clang-tidy
        on individual cc_library / cc_binary / cc_test targets.

    Example usage in a BUILD file:
        load("//tools/lint:linters.bzl", "clang_tidy_test")
        clang_tidy_test(name = "my_lib_tidy", srcs = [":my_lib"])
    """
    return lint_test(aspect = aspect)
