// *******************************************************************************
// Copyright (c) 2026 Contributors to the Eclipse Foundation
//
// See the NOTICE file(s) distributed with this work for additional
// information regarding copyright ownership.
//
// This program and the accompanying materials are made available under the
// terms of the Apache License Version 2.0 which is available at
// https://www.apache.org/licenses/LICENSE-2.0
//
// SPDX-License-Identifier: Apache-2.0
// *******************************************************************************

// Intentional -Wunused-variable violation (part of `all_wall_warnings`).
// This file exists to document what all_wall_warnings catches.
// It must NOT be included in the regular test build (tags = ["manual"]).
//
// Verify with:
//   bazel build --config=feature_only_gcc_all_wall_warnings :all_wall_warnings_violation
//     -> fails (warnings_as_errors is bundled into the config)
//   bazel build --extra_toolchains=@score_gcc_toolchain_15//:x86_64-linux-gcc_15.3.0 :all_wall_warnings_violation
//     -> succeeds silently (no warnings feature enabled)

int compute() {
    int unused_value = 42;  // -Wunused-variable
    return 0;
}
