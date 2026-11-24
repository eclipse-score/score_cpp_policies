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

"""Sanitizer runtime libraries of the resolved C++ toolchain."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")

def _is_soname(basename, lib):
    # Matches the SONAME (e.g. libasan.so.8), not the dev symlink or the fully versioned file.
    prefix = lib + ".so."
    return basename.startswith(prefix) and basename[len(prefix):].isdigit()

def _sanitizer_runtime_libs_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    # Toolchain packages ship the same library under several paths (e.g. lib64/ and sysroot/lib/);
    # one per name keeps packaging rules free of duplicate destinations.
    by_name = {}
    for f in cc_toolchain.all_files.to_list():
        if f.basename not in by_name and [lib for lib in ctx.attr.libs if _is_soname(f.basename, lib)]:
            by_name[f.basename] = f
    return [DefaultInfo(files = depset(by_name.values()))]

sanitizer_runtime_libs = rule(
    implementation = _sanitizer_runtime_libs_impl,
    attrs = {
        "libs": attr.string_list(
            default = ["libasan", "liblsan", "libtsan", "libubsan"],
            doc = "Library names (without .so.N) to pick from the toolchain files.",
        ),
    },
    toolchains = use_cc_toolchain(),
    fragments = ["cpp"],
    doc = "Shared sanitizer runtimes (lib*.so.N) shipped with the resolved C++ toolchain.",
)
