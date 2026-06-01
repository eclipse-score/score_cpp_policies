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

WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load sanitizer environment files in deterministic (sorted) order.
# Each *.env file may reference paths relative to the sanitizers directory;
# sed rewrites those references to absolute paths before sourcing.
# Sorted order guarantees reproducibility across filesystem implementations.
# Each variable is only exported once (first definition wins), so there is no
# silent clobber when two sanitizer env files set the same variable — the
# earlier file (alphabetically) takes precedence.
readarray -t _env_files < <(
    find "$WRAPPER_DIR" -maxdepth 1 -name '*_relative_sanitizer.env' -print | sort
)

for env_file in "${_env_files[@]}"; do
    [ -f "$env_file" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        var_name="${line%%=*}"
        # Only export if the variable has not already been set by a previous
        # env file.  This makes the effective value deterministic (first wins).
        if [[ -z "${!var_name+x}" ]]; then
            export "${line?}"
        fi
    done < <(sed "s|\./sanitizers/|$WRAPPER_DIR/|g" "$env_file")
done

exec "$@"
