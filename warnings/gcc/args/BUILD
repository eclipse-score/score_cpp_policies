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

load("@rules_cc//cc/toolchains:args_list.bzl", "cc_args_list")

# Each level implies the previous one, e.g. "strict" also enables "minimal".
_WARNING_LEVELS = [
    "minimal",
    "strict",
    "all",
]

[
    cc_args_list(
        name = level + "_warnings_args",
        args = select({
            "@platforms//os:linux": [
                "@score_cpp_policies//warnings/gcc/args/linux:{}_warnings_args".format(level),
                "@score_cpp_policies//warnings/gcc/args/linux:{}_c_warnings_args".format(level),
                "@score_cpp_policies//warnings/gcc/args/linux:{}_cxx_warnings_args".format(level),
            ],
            "@platforms//os:qnx": [
                "@score_cpp_policies//warnings/gcc/args/qnx:{}_warnings_args".format(level),
                "@score_cpp_policies//warnings/gcc/args/qnx:{}_c_warnings_args".format(level),
                "@score_cpp_policies//warnings/gcc/args/qnx:{}_cxx_warnings_args".format(level),
            ],
        }),
        visibility = ["//visibility:public"],
    )
    for i, level in enumerate(_WARNING_LEVELS)
]

cc_args_list(
    name = "warnings_as_errors_args",
    args = select({
        "@platforms//os:linux": [
            "@score_cpp_policies//warnings/gcc/args/linux:warnings_as_errors_args",
        ],
        "@platforms//os:qnx": [
            "@score_cpp_policies//warnings/gcc/args/qnx:warnings_as_errors_args",
        ],
    }),
    visibility = ["//visibility:public"],
)
