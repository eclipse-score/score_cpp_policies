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

#include <gtest/gtest.h>
#include <atomic>
#include <memory>
#include <thread>
#include <vector>

// Simple test that should pass with all sanitizers
TEST(SampleTest, BasicFunctionality) {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    EXPECT_EQ(vec.size(), 5);
    EXPECT_EQ(vec[0], 1);
    EXPECT_EQ(vec[4], 5);
}

// Memory allocation test that should pass with all sanitizers
TEST(SampleTest, MemoryAllocation) {
    auto ptr = std::make_unique<int>(42);
    EXPECT_EQ(*ptr, 42);
}

// Test with multiple threads using proper synchronization (atomics)
// Validates that thread-safe code passes ASan/UBSan/LSan cleanly
TEST(SampleTest, MultiThreaded) {
    std::atomic<int> counter{0};
    
    auto increment = [&counter]() {
        for (int i = 0; i < 1000; ++i) {
            counter.fetch_add(1, std::memory_order_relaxed);
        }
    };
    
    std::vector<std::thread> threads;
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back(increment);
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    EXPECT_EQ(counter.load(), 4000);
}

// Basic arithmetic test that should pass with all sanitizers
TEST(SampleTest, NoUndefinedBehavior) {
    int x = 5;
    int y = 2;
    EXPECT_EQ(x / y, 2);
    EXPECT_EQ(x % y, 1);
}
