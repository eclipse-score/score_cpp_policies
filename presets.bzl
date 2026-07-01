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

"""Single entry point for all score_cpp_policies bazelrc-preset.bzl presets.

Consumers wanting every policy this repo ships should load PRESETS:

    load("@score_cpp_policies//:presets.bzl", "PRESETS")

    bazelrc_preset(
        name = "preset",
        extra_presets = PRESETS,
    )

Consumers wanting only one policy (e.g. sanitizers without clang-tidy) can load the
individual dicts instead: SANITIZER_PRESETS, CLANG_TIDY_PRESETS.

Coverage and CodeQL are not included here yet.
"""

load("//clang_tidy:presets.bzl", "CLANG_TIDY_PRESETS")
load("//sanitizers:presets.bzl", "SANITIZER_PRESETS")

PRESETS = SANITIZER_PRESETS | CLANG_TIDY_PRESETS
