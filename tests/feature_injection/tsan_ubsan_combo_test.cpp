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

// Verifies both sanitizers are active at the same time.
#if !__has_feature(thread_sanitizer)
#error "score_tsan not active in tsan+ubsan combination"
#endif
#if !__has_feature(undefined_behavior_sanitizer)
#error "score_ubsan not active in tsan+ubsan combination"
#endif

int main() { return 0; }
