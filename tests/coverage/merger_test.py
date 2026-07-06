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
"""Unit tests for the coverage merger's argument parsing."""

import sys
import unittest
from unittest import mock

from coverage.merger import parse_args


class ParseArgsTest(unittest.TestCase):
    def test_llvm_profdata_is_required(self):
        argv = [
            "merger",
            "--coverage_dir=/tmp/cov",
            "--output_file=/tmp/out.zip",
            "--source_file_manifest=/tmp/manifest.txt",
        ]
        with mock.patch.object(sys, "argv", argv):
            with self.assertRaises(SystemExit):
                parse_args()

    def test_llvm_profdata_is_captured(self):
        argv = [
            "merger",
            "--coverage_dir=/tmp/cov",
            "--output_file=/tmp/out.zip",
            "--source_file_manifest=/tmp/manifest.txt",
            "--llvm_profdata=/wrapper/llvm-profdata",
        ]
        with mock.patch.object(sys, "argv", argv):
            args = parse_args()
        self.assertEqual(args.llvm_profdata, "/wrapper/llvm-profdata")


if __name__ == "__main__":
    unittest.main()
