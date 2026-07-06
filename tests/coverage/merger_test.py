#!/usr/bin/env python3
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
"""Unit tests for the coverage merger's llvm-profdata resolution logic."""

import os
import unittest
from unittest import mock

from coverage.merger import _resolve_llvm_profdata


class ResolveLlvmProfdataTest(unittest.TestCase):
    def test_prefers_explicit_path_over_env_var(self):
        with mock.patch.dict(os.environ, {"LLVM_PROFDATA": "/env/llvm-profdata"}):
            self.assertEqual(
                _resolve_llvm_profdata("/wrapper/llvm-profdata"),
                "/wrapper/llvm-profdata",
            )

    def test_falls_back_to_env_var_when_no_explicit_path(self):
        with mock.patch.dict(os.environ, {"LLVM_PROFDATA": "/env/llvm-profdata"}):
            self.assertEqual(_resolve_llvm_profdata(None), "/env/llvm-profdata")

    def test_exits_when_neither_is_set(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(SystemExit):
                _resolve_llvm_profdata(None)


if __name__ == "__main__":
    unittest.main()
