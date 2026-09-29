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

int main(int argc, char **argv) {
  int x = 100;
  float *y = (float*)&x;
  *y += 2.0f;          // Strict aliasing violation
  return 0;
}

// this example was copied from the TypeSanitizer documentation (https://clang.llvm.org/docs/TypeSanitizer.html)