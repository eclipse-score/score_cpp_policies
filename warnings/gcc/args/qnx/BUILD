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
# All minimal compiler warnings (opt-in via extra_enabled_features, not on by default).
# --------------------------------------------------------------------------------
cc_args(
    name = "minimal_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
    ],
    args = [
        "-Wall",
        "-Wno-error=deprecated-declarations",
        "-Wno-error=cpp",
        "-Wno-format-y2k",
        "-Wno-free-nonheap-object",
        # -Wmaybe-uninitialized is disabled due to a bug in gcc8 and gcc9 https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80635
        # most issues will be covered anyway with -Wuninitialized (enabled with -Wall) and UB sanitizers
        "-Wno-maybe-uninitialized",
        "-Wunused-but-set-parameter",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "minimal_c_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile_actions",
    ],
    args = [],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "minimal_cxx_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wno-literal-suffix",
        "-Wno-noexcept-type",
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
        "-Wextra",
        "-pedantic",
        "-Warray-bounds=2",
        "-Wcast-align",
        "-Wcast-qual",
        "-Wdisabled-optimization",
        "-Wfloat-conversion",
        "-Wformat=2",
        "-Wimplicit-fallthrough=4",
        "-Winvalid-pch",
        "-Wmissing-format-attribute",
        "-Wmultichar",
        "-Wpacked",
        "-Wscalar-storage-order",
        "-Wsuggest-attribute=format",
        "-Wundef",
        "-Wunused-macros",
        "-Wvector-operation-performance",
        "-Wwrite-strings",
        "-Wformat-security",
        "-Wlogical-op",
        "-Wredundant-decls",
        "-Wshadow",
        "-Wconversion",
        "-Wsign-conversion",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "strict_c_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:c_compile_actions",
    ],
    args = [
        "-Wold-style-definition",
        "-Wstrict-prototypes",
    ],
    visibility = ["//visibility:public"],
)

cc_args(
    name = "strict_cxx_warnings_args",
    actions = [
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions",
    ],
    args = [
        "-Wdelete-non-virtual-dtor",
        "-Woverloaded-virtual",
        "-Wregister",
        "-Wstrict-null-sentinel",
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
        "-Wframe-address",
        "-Winfinite-recursion",
        "-Winit-self",
        "-Wint-in-bool-context",
        "-Wmain",
        # -Wmaybe-uninitialized stays disabled here too, see minimal_warnings_args.
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
        "-Wmismatched-new-delete",
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
    ],
    visibility = ["//visibility:public"],
)