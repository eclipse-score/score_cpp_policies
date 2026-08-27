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

// Must compile clean under minimal/strict/all_wall_warnings, even combined with
// warnings_as_errors (-Werror) — proves the policy has no false positives on
// idiomatic code. See feature_only_gcc_{minimal,strict,all_wall}_warnings in .bazelrc.

#include <cstdint>

namespace {

std::uint32_t add(std::uint32_t a, std::uint32_t b) {
    return a + b;
}

}  // namespace

int main() {
    const std::uint32_t result = add(2, 3);
    return result == 5 ? 0 : 1;
}
