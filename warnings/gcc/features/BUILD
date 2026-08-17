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

load("@rules_cc//cc/toolchains:feature.bzl", "cc_feature")

# Each level implies the previous one, e.g. "strict" also enables "minimal".
_WARNING_LEVELS = [
    "minimal",
    "strict",
    "all",
]

[
    cc_feature(
        name = level + "_warnings",
        args = ["@score_cpp_policies//warnings/gcc/args:{}_warnings_args".format(level)],
        feature_name = level + "_warnings",
        implies = [_WARNING_LEVELS[i - 1] + "_warnings"] if i > 0 else [],
        visibility = ["//visibility:public"],
    )
    for i, level in enumerate(_WARNING_LEVELS)
]

cc_feature(
    name = "warnings_as_errors",
    args = ["@score_cpp_policies//warnings/gcc/args:warnings_as_errors_args"],
    feature_name = "warnings_as_errors",
    visibility = ["//visibility:public"],
)
