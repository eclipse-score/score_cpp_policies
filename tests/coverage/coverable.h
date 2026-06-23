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

#ifndef SCORE_CPP_POLICIES_TESTS_COVERAGE_COVERABLE_H_
#define SCORE_CPP_POLICIES_TESTS_COVERAGE_COVERABLE_H_

namespace score::cpp_policies::tests {

// Minimal API exercised by the coverage smoke test. Two branches are exposed
// so the report has both a covered and an uncovered branch to verify the
// HTML / LCOV pipeline end-to-end.
int classify(int value) noexcept;

}  // namespace score::cpp_policies::tests

#endif  // SCORE_CPP_POLICIES_TESTS_COVERAGE_COVERABLE_H_
