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

#include "coverage/coverable.h"

#include <gtest/gtest.h>

namespace score::cpp_policies::tests {
namespace {

// Intentionally only covers the negative and zero branches — the positive
// branch should appear in the coverage report as uncovered, exercising the
// "uncovered branch" rendering path.
TEST(ClassifyTest, NegativeAndZero) {
    EXPECT_EQ(classify(-5), -1);
    EXPECT_EQ(classify(0), 0);
}

}  // namespace
}  // namespace score::cpp_policies::tests
