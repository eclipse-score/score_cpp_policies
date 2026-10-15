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

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:feature.bzl", "cc_feature")

# gcc warnings from the MISRA C++:2023 Guideline Enforcement Plan (GEP):
# https://github.com/eclipse-score/communication/blob/main/quality/static_analysis/misra_gep.md
cc_args(
    name = "args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wtype-limits",
        "-Wunused-variable",
        "-Wunused-local-typedefs",
        "-Wunused-function",
        "-Wtrigraphs",
        "-Wcomment",
        "-Wparentheses",
        "-Wshadow",
        "-Wreturn-local-addr",
        "-Wswitch-bool",
        "-Wsign-compare",
        "-Wconversion",
        "-Wfloat-conversion",
        "-Waddress",
        "-Wcast-function-type",
        "-Wdangling-else",
        "-Wmisleading-indentation",
        "-Wreturn-type",
        "-Wignored-qualifiers",
        "-Wenum-compare",
        "-Wuninitialized",
        "-Wterminate",
        "-Wexpansion-to-defined",
        "-Wdelete-incomplete",
    ],
)

cc_feature(
    name = "misra_cpp_2023",
    args = ["@score_cpp_policies//warnings/gcc/features/misra_cpp_2023:args"],
    feature_name = "misra_cpp_2023_warnings",
    visibility = ["//visibility:public"],
)
