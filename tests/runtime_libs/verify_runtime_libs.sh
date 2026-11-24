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

echo "runtime_libs: $*"

missing=0
for lib in libasan liblsan libtsan libubsan; do
    found=()
    for file in "$@"; do
        if [[ "$(basename "$file")" =~ ^${lib}\.so\.[0-9]+$ && -s "$file" ]]; then
            found+=("$file")
        fi
    done
    if [[ ${#found[@]} -ne 1 ]]; then
        echo "FAIL: expected exactly one ${lib}.so.N in runtime_libs, got ${#found[@]}"
        missing=1
    else
        echo "OK: ${found[0]}"
    fi
done

exit "$missing"
