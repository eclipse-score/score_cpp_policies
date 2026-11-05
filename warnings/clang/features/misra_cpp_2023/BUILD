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

# clang warnings from the MISRA C++:2023 Guideline Enforcement Plan (GEP):
# https://github.com/eclipse-score/communication/blob/main/quality/static_analysis/misra_gep.md
cc_args(
    name = "args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wunreachable-code",
        "-Wunreachable-code-return",
        "-Wtautological-unsigned-zero-compare",
        "-Wtautological-type-limit-compare",
        "-Wunused-variable",
        "-Wunused-exception-parameter",
        "-Wunused-lambda-capture",
        "-Wunused-parameter",
        "-Wunused-function",
        "-Wunused-member-function",
        "-Wunused-template",
        "-Wdeprecated",
        "-Wsequence-point",
        "-Wunsequenced",
        "-Wtrigraphs",
        "-Wcomment",
        "-Wuser-defined-literals",
        "-Wunknown-escape-sequence",
        "-Wredundant-parens",
        "-Wvexing-parse",
        "-Wshadow-all",
        "-Wreturn-stack-address",
        "-Wswitch-bool",
        "-Wconstant-conversion",
        "-Wimplicit-int-conversion",
        "-Wshift-sign-overflow",
        "-Wsign-compare",
        "-Wc++11-narrowing",
        "-Wsign-conversion",
        "-Wzero-as-null-pointer-constant",
        "-Wtautological-pointer-compare",
        "-Wparentheses",
        "-Wreinterpret-base-class",
        "-Wold-style-cast",
        "-Wcast-qual",
        "-Wpointer-to-int-cast",
        "-Winfinite-recursion",
        "-Warray-bounds",
        "-Warray-bounds-pointer-arithmetic",
        "-Wcomma",
        "-Wunused-value",
        "-Wdangling-else",
        "-Wmisleading-indentation",
        "-Wempty-body",
        "-Wimplicit-fallthrough",
        "-Wswitch",
        "-Wswitch-default",
        "-Wswitch-enum",
        "-Wdangling-gsl",
        "-Winvalid-noreturn",
        "-Wreturn-type",
        "-Wignored-qualifiers",
        "-Wshadow",
        "-Wenum-compare",
        "-Wuninitialized",
        "-Wduplicate-enum",
        "-Winconsistent-missing-destructor-override",
        "-Winconsistent-missing-override",
        "-Wextra-semi-stmt",
        "-Wcall-to-pure-virtual-from-ctor-dtor",
        "-Wexceptions",
        "-Wexpansion-to-defined",
        "-Wundef",
        "-Wendif-labels",
        "-Wextra-tokens",
        "-Wembedded-directive",
        "-Wpragma-once-outside-header",
        "-Wdelete-incomplete",
    ],
)

cc_feature(
    name = "misra_cpp_2023",
    args = ["@score_cpp_policies//warnings/clang/features/misra_cpp_2023:args"],
    feature_name = "misra_cpp_2023_warnings",
    visibility = ["//visibility:public"],
)
