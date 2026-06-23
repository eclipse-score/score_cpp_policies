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

#ifndef SCORE_CPP_POLICIES_TESTS_COVERAGE_UNCOVERED_H_
#define SCORE_CPP_POLICIES_TESTS_COVERAGE_UNCOVERED_H_

namespace score::cpp_policies::tests {

// Intentionally not linked into any cc_test. Used to verify that the reporter
// surfaces source files that no test exercises as 0%-coverage entries instead
// of silently dropping them.
int never_called(int value) noexcept;

}  // namespace score::cpp_policies::tests

#endif  // SCORE_CPP_POLICIES_TESTS_COVERAGE_UNCOVERED_H_
