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

# --------------------------------------------------------------------------------
# All minimal compiler warnings (enabled by default).
# --------------------------------------------------------------------------------
cc_args(
    name = "minimal_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Wall",
        "-Wcast-align",
        "-Wcast-qual",
        "-Wformat-nonliteral",
        "-Wformat-signedness",
        "-Wformat=2",
        "-Wmissing-format-attribute",
        "-Wpointer-arith",
        "-Wredundant-decls",
        "-Wreturn-local-addr",
        "-Wsizeof-array-argument",
        "-Wundef",
        "-Wwrite-strings",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "minimal_c_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile_actions",
    ],
    args = [
        "-Wbad-function-cast",
        "-Wmissing-prototypes",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "minimal_cxx_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wodr",
        "-Wreorder",
    ],
    visibility = ["//visibility:public"],
)

# --------------------------------------------------------------------------------
# All strict compiler warnings.
# --------------------------------------------------------------------------------
cc_args(
    name = "strict_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Wbool-compare",
        "-Wconversion",
        "-Wdouble-promotion",
        "-Wextra",
        "-Winvalid-pch",
        "-Wlogical-not-parentheses",
        "-Wlogical-op",
        "-Wpedantic",
        "-Wswitch-bool",
        "-Wunused-but-set-parameter",
        "-Wvla",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "strict_c_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile_actions",
    ],
    args = [],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "strict_cxx_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wnarrowing",
    ],
    visibility = ["//visibility:public"],
)

# --------------------------------------------------------------------------------
# All compiler warnings.
# --------------------------------------------------------------------------------
cc_args(
    name = "all_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Waddress",
        "-Warray-bounds=1",
        "-Warray-compare",
        "-Warray-parameter=2",
        "-Wbool-operation",
        "-Wchar-subscripts",
        "-Wcomment",
        "-Wdangling-else",
        "-Wdangling-pointer=2",
        "-Wduplicate-decl-specifier",
        "-Wenum-compare",
        "-Wformat-contains-nul",
        "-Wformat-diag",
        "-Wformat-extra-args",
        "-Wformat-overflow=1",
        "-Wformat-truncation=1",
        "-Wformat-zero-length",
        "-Wformat=1",
        "-Wframe-address",
        "-Winfinite-recursion",
        "-Winit-self",
        "-Wint-in-bool-context",
        "-Wmain",
        "-Wmaybe-uninitialized",
        "-Wmemset-elt-size",
        "-Wmemset-transposed-args",
        "-Wmisleading-indentation",
        "-Wmismatched-dealloc",
        "-Wmissing-attributes",
        "-Wmissing-braces",
        "-Wmultistatement-macros",
        "-Wnonnull",
        "-Wnonnull-compare",
        "-Wopenmp-simd",
        "-Wpacked-not-aligned",
        "-Wparentheses",
        "-Wrestrict",
        "-Wreturn-type",
        "-Wsequence-point",
        "-Wsign-compare",
        "-Wsizeof-array-div",
        "-Wsizeof-pointer-div",
        "-Wsizeof-pointer-memaccess",
        "-Wstrict-aliasing",
        "-Wstrict-overflow=1",
        "-Wswitch",
        "-Wtautological-compare",
        "-Wtrigraphs",
        "-Wuninitialized",
        "-Wunknown-pragmas",
        "-Wunused",
        "-Wunused-but-set-variable",
        "-Wunused-const-variable=1",
        "-Wunused-function",
        "-Wunused-label",
        "-Wunused-local-typedefs",
        "-Wunused-value",
        "-Wunused-variable",
        "-Wuse-after-free=2",
        "-Wvolatile-register-var",
        "-Wzero-length-bounds",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "all_c_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile_actions",
    ],
    args = [
        "-Wimplicit",
        "-Wimplicit-function-declaration",
        "-Wimplicit-int",
        "-Wpointer-sign",
        "-Wvla-parameter",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "all_cxx_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Waligned-new",
        "-Wc++11-compat",
        "-Wc++14-compat",
        "-Wc++17-compat",
        "-Wc++20-compat",
        "-Wcatch-value",
        "-Wclass-memaccess",
        "-Wdelete-non-virtual-dtor",
        "-Wmismatched-new-delete",
        "-Woverloaded-virtual",
        "-Wpessimizing-move",
        "-Wrange-loop-construct",
        "-Wuseless-cast",
    ],
    visibility = ["//visibility:public"],
)

# --------------------------------------------------------------------------------
# Treat all warnings as errors.
# --------------------------------------------------------------------------------
cc_args(
    name = "warnings_as_errors_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Werror",
        "-Wno-error=deprecated-declarations",
    ],
    visibility = ["//visibility:public"],
)
