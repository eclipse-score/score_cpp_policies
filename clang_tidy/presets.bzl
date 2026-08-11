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

"""bazelrc-preset.bzl extra_presets for the clang-tidy policy.

Mirrors the `test:clang-tidy` flags in clang_tidy.bazelrc, for consumers using
bazelrc-preset.bzl (https://github.com/bazel-contrib/bazelrc-preset.bzl) instead of
`import`.

The `aspects` value is a label relative to the consuming repo, not score_cpp_policies
— each consumer defines its own `tools/lint/linters.bzl` (see clang_tidy/README.md).
"""

# buildifier: keep-sorted
CLANG_TIDY_PRESETS = {
    "aspects": struct(
        command = "test:clang-tidy",
        default = "//tools/lint:linters.bzl%clang_tidy_aspect",
        description = "Run the consumer's clang-tidy aspect (see clang_tidy/README.md step 3-4) under --config=clang-tidy.",
    ),
    "extra_toolchains": struct(
        command = "test:clang-tidy",
        default = "@llvm_toolchain//:cc-toolchain-x86_64-linux",
        description = "Use the LLVM toolchain registered by the consumer's llvm_toolchain extension for clang-tidy.",
    ),
    "output_groups": struct(
        command = "test:clang-tidy",
        default = "+rules_lint_report",
        description = "Surface the rules_lint_report output group produced by the clang-tidy aspect.",
    ),
}
