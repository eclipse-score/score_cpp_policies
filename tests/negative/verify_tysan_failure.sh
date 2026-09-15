#!/usr/bin/env bash

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

set -euo pipefail

# Unlike other sanitizers, TypeSanitizer's runtime does not honor
# halt_on_error/exitcode (unimplemented in the runtime): the instrumented
# binary always exits 0 even when it reports violations. So we verify
# detection by scanning output for the error marker instead of the exit code.

BINARY="$1"

echo "Running: $BINARY"

OUTPUT="$("$BINARY" 2>&1)" || true
echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "TypeSanitizer: type-aliasing-violation"; then
    echo "✓ PASS: TypeSanitizer reported a type-aliasing violation"
    exit 0
else
    echo "✗ FAIL: No TypeSanitizer violation reported in output"
    exit 1
fi
