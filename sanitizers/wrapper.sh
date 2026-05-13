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

IFS='
'
# shellcheck disable=SC2046
export $(sed "s|\./sanitizers/|$WRAPPER_DIR/|g" "$WRAPPER_DIR/relative_sanitizer.env" | grep -v '^#' | grep -v '^$')
exec "$@"
