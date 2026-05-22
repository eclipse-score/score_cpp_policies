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

// Intentional bugprone-use-after-move violation.
// This file exists to document what the clang-tidy aspect catches.
// It must NOT be included in the regular test build.
// Run with: bazel test --config=clang-tidy :clang_tidy_violation_check

#include <memory>
#include <utility>

int intentional_use_after_move() {
    auto p = std::make_unique<int>(42);
    auto q = std::move(p);
    return *p;  // bugprone-use-after-move: p was moved into q
}
