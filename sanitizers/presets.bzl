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

"""bazelrc-preset.bzl extra_presets for the sanitizers policy.

Mirrors the --config=asan/ubsan/lsan/tsan/asan_ubsan_lsan/tsan_ubsan flags in
sanitizers.bazelrc, for consumers using bazelrc-preset.bzl
(https://github.com/bazel-contrib/bazelrc-preset.bzl) instead of `import`.
"""

_WRAPPER = "@score_cpp_policies//sanitizers:wrapper"

# buildifier: keep-sorted
SANITIZER_PRESETS = {
    "@score_cpp_policies//sanitizers/flags:asan": struct(
        command = "build:asan",
        default = True,
        description = "Activate the ASan cc_feature (score_asan) for the //sanitizers/flags:asan_on config_setting.",
    ),
    "@score_cpp_policies//sanitizers/flags:lsan": struct(
        command = "build:lsan",
        default = True,
        description = "Activate the LSan cc_feature (score_lsan) for the //sanitizers/flags:lsan_on config_setting.",
    ),
    "@score_cpp_policies//sanitizers/flags:tsan": struct(
        command = "build:tsan",
        default = True,
        description = "Activate the TSan cc_feature (score_tsan) for the //sanitizers/flags:tsan_on config_setting.",
    ),
    "@score_cpp_policies//sanitizers/flags:ubsan": struct(
        command = "build:ubsan",
        default = True,
        description = "Activate the UBSan cc_feature (score_ubsan) for the //sanitizers/flags:ubsan_on config_setting.",
    ),
    "config": [
        struct(
            command = "build:asan",
            default = "with_debug_symbols",
            description = "Keep debug symbols (-g1, --strip=never) so sanitizer stack traces are readable.",
        ),
        struct(
            command = "build:ubsan",
            default = "with_debug_symbols",
            description = "Keep debug symbols (-g1, --strip=never) so sanitizer stack traces are readable.",
        ),
        struct(
            command = "build:lsan",
            default = "with_debug_symbols",
            description = "Keep debug symbols (-g1, --strip=never) so sanitizer stack traces are readable.",
        ),
        struct(
            command = "build:tsan",
            default = "with_debug_symbols",
            description = "Keep debug symbols (-g1, --strip=never) so sanitizer stack traces are readable.",
        ),
        struct(
            command = "build:asan_ubsan_lsan",
            default = "asan",
            allow_repeated = True,
            description = "Composite config: address + leak + UB checking together.",
        ),
        struct(
            command = "build:asan_ubsan_lsan",
            default = "ubsan",
            allow_repeated = True,
            description = "Composite config: address + leak + UB checking together.",
        ),
        struct(
            command = "build:asan_ubsan_lsan",
            default = "lsan",
            allow_repeated = True,
            description = "Composite config: address + leak + UB checking together.",
        ),
        struct(
            command = "build:tsan_ubsan",
            default = "tsan",
            allow_repeated = True,
            description = "Composite config: thread + UB checking together.",
        ),
        struct(
            command = "build:tsan_ubsan",
            default = "ubsan",
            allow_repeated = True,
            description = "Composite config: thread + UB checking together.",
        ),
    ],
    "features": [
        struct(
            command = "test:with_debug_symbols",
            default = "debug_symbols",
            description = "Emit -g1 debug info under any sanitizer config so stack traces resolve symbols.",
        ),
        struct(
            command = "build:asan",
            default = "score_asan",
            description = "Compile/link with -fsanitize=address via the score_asan cc_feature.",
        ),
        struct(
            command = "build:ubsan",
            default = "score_ubsan",
            description = "Compile/link with -fsanitize=undefined via the score_ubsan cc_feature.",
        ),
        struct(
            command = "build:lsan",
            default = "score_lsan",
            description = "Compile/link with -fsanitize=leak via the score_lsan cc_feature.",
        ),
        struct(
            command = "build:tsan",
            default = "score_tsan",
            description = "Compile/link with -fsanitize=thread via the score_tsan cc_feature.",
        ),
    ],
    "platform_suffix": [
        struct(
            command = "build:asan",
            default = "asan",
            description = "Disambiguate the asan output tree from plain builds.",
        ),
        struct(
            command = "build:ubsan",
            default = "ubsan",
            description = "Disambiguate the ubsan output tree from plain builds.",
        ),
        struct(
            command = "build:lsan",
            default = "lsan",
            description = "Disambiguate the lsan output tree from plain builds.",
        ),
        struct(
            command = "build:tsan",
            default = "tsan",
            description = "Disambiguate the tsan output tree from plain builds.",
        ),
        struct(
            command = "build:asan_ubsan_lsan",
            default = "asan_ubsan_lsan",
            description = "Canonical suffix for the composite asan+ubsan+lsan config, overriding the per-sanitizer suffixes.",
        ),
        struct(
            command = "build:tsan_ubsan",
            default = "tsan_ubsan",
            description = "Canonical suffix for the composite tsan+ubsan config, overriding the per-sanitizer suffixes.",
        ),
    ],
    "run_under": [
        struct(
            command = "test:asan",
            default = _WRAPPER,
            description = "Run tests under the sanitizers wrapper so suppressions/options env files are applied.",
        ),
        struct(
            command = "test:ubsan",
            default = _WRAPPER,
            description = "Run tests under the sanitizers wrapper so suppressions/options env files are applied.",
        ),
        struct(
            command = "test:lsan",
            default = _WRAPPER,
            description = "Run tests under the sanitizers wrapper so suppressions/options env files are applied.",
        ),
        struct(
            command = "test:tsan",
            default = _WRAPPER,
            description = "Run tests under the sanitizers wrapper so suppressions/options env files are applied.",
        ),
    ],
    "strip": struct(
        command = "build:with_debug_symbols",
        default = "never",
        description = "Never strip symbols under any sanitizer config so stack traces remain readable.",
    ),
}
