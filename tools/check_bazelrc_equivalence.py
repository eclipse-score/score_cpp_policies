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

"""Compares a legacy .bazelrc fragment (e.g. sanitizers/sanitizers.bazelrc) against a
bazelrc-preset.bzl-generated file, restricted to the commands the legacy file defines
(e.g. "build:asan").

Usage: check_bazelrc_equivalence.py <legacy_file> <generated_file>
"""

import re
import sys

_LINE_RE = re.compile(r"^([A-Za-z0-9_:-]+)\s+--(.+)$")


def normalize(path, filter_commands=None):
    """Returns the sorted set of (command, flag, value) tuples in a .bazelrc file."""
    entries = set()
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            match = _LINE_RE.match(line)
            if not match:
                continue
            cmd, rest = match.group(1), match.group(2)
            if filter_commands is not None and cmd not in filter_commands:
                continue
            if rest.startswith("no") and "=" not in rest:
                flag, val = rest[2:], "False"
            elif "=" in rest:
                flag, val = rest.split("=", 1)
                val = val.strip('"')
            else:
                flag, val = rest, "True"
            entries.add((cmd, flag, val))
    return entries


def main(legacy_file, generated_file):
    legacy = normalize(legacy_file)
    commands = {cmd for cmd, _, _ in legacy}
    generated = normalize(generated_file, filter_commands=commands)

    if legacy != generated:
        print(f"MISMATCH between {legacy_file} and {generated_file} (commands: {sorted(commands)})", file=sys.stderr)
        for entry in sorted(legacy - generated):
            print(f"  only in {legacy_file}: {entry}", file=sys.stderr)
        for entry in sorted(generated - legacy):
            print(f"  only in {generated_file}: {entry}", file=sys.stderr)
        return 1

    print(f"OK: {legacy_file} matches {generated_file} for commands: {sorted(commands)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
