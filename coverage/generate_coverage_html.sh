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
#
# Generic post-`bazel coverage` driver shipped by @score_cpp_policies.
#
# Extracts the HTML coverage report from the llvm-cov generated zip produced
# by `bazel coverage`. Optionally runs the justification post-processor and/or
# assembles a CI archive with HTML + LCOV + JUnit XMLs.
#
# Run via Bazel from the CONSUMER repository:
#
#   bazel run @score_cpp_policies//coverage:generate_coverage_html -- \
#       [--yaml <path/to/coverage_justifications.yaml>] \
#       [--output-dir <dir>] \
#       [--archive <archive-name>] \
#       [--junit-glob <glob>]
#
# Arguments:
#   --yaml         Path (relative to workspace root, or absolute) to the
#                  consumer's coverage_justifications.yaml. If omitted (or the
#                  file does not exist), justification post-processing is
#                  skipped.
#   --output-dir   Directory (relative to workspace root, or absolute) into
#                  which the HTML report is written. Default: cpp_coverage
#   --archive      If set, also create <archive-name>.zip containing the HTML
#                  report, raw LCOV data and matched JUnit XMLs.
#   --junit-glob   Glob (relative to workspace root) used when --archive is
#                  set, to locate test.xml files. Default: bazel-testlogs/**

set -euo pipefail

JUSTIFICATION_YAML=""
OUTPUT_DIR="cpp_coverage"
ARCHIVE_NAME=""
JUNIT_GLOB="bazel-testlogs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yaml)
      JUSTIFICATION_YAML="${2:?--yaml requires a path argument}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?--output-dir requires a directory argument}"
      shift 2
      ;;
    --archive)
      ARCHIVE_NAME="${2:?--archive requires a name argument}"
      shift 2
      ;;
    --junit-glob)
      JUNIT_GLOB="${2:?--junit-glob requires a glob argument}"
      shift 2
      ;;
    -h|--help)
      sed -n '17,42p' "$0" >&2
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "       Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "ERROR: BUILD_WORKSPACE_DIRECTORY is not set. This script must be run via 'bazel run'." >&2
  exit 1
fi

# Locate the justify and effective_coverage binaries from the runfiles tree
# (they are declared as `data` deps of this sh_binary).  Invoking them directly
# avoids a nested `bazel run` which would deadlock on Bazel's output-base lock.
_rlocation() {
  local rlpath="${RUNFILES_DIR:-$0.runfiles}/${1}"
  if [[ -x "${rlpath}" ]]; then echo "${rlpath}"; return 0; fi
  # Fallback: try manifest (useful when RUNFILES_DIR is not set).
  if [[ -f "${RUNFILES_DIR:-$0.runfiles}_manifest" ]]; then
    local entry
    entry=$(grep -F "${1} " "${RUNFILES_DIR:-$0.runfiles}_manifest" | head -1 | cut -d' ' -f2-)
    if [[ -x "${entry}" ]]; then echo "${entry}"; return 0; fi
  fi
  echo "ERROR: runfile not found: ${1}" >&2
  exit 1
}

_JUSTIFY=$(_rlocation "score_cpp_policies+/coverage/justify")
_EFFECTIVE_COVERAGE=$(_rlocation "score_cpp_policies+/coverage/effective_coverage")

cd "${BUILD_WORKSPACE_DIRECTORY}"

# Resolve relative paths against the workspace root.
case "${OUTPUT_DIR}" in
  /*) ;;
  *)  OUTPUT_DIR="${BUILD_WORKSPACE_DIRECTORY}/${OUTPUT_DIR}" ;;
esac

if [[ -n "${JUSTIFICATION_YAML}" ]]; then
  case "${JUSTIFICATION_YAML}" in
    /*) ;;
    *)  JUSTIFICATION_YAML="${BUILD_WORKSPACE_DIRECTORY}/${JUSTIFICATION_YAML}" ;;
  esac
fi

# Coverage report generator output (the zip our reporter produced).
COVERAGE_ZIP="${BUILD_WORKSPACE_DIRECTORY}/bazel-out/_coverage/_coverage_report.dat"

if [[ ! -f "${COVERAGE_ZIP}" ]]; then
  echo "ERROR: Coverage report not found at ${COVERAGE_ZIP}" >&2
  echo "       Run 'bazel coverage //... --build_tests_only' first." >&2
  exit 1
fi

# Extract the HTML report from the zip.
TMPDIR_EXTRACT="${TMPDIR:-/tmp}/coverage_extract_$$"
mkdir -p "${TMPDIR_EXTRACT}"
trap 'rm -rf "${TMPDIR_EXTRACT}"' EXIT

unzip -q -o "${COVERAGE_ZIP}" -d "${TMPDIR_EXTRACT}"

rm -rf "${OUTPUT_DIR}"
if [[ -d "${TMPDIR_EXTRACT}/html_report" ]]; then
  cp -r "${TMPDIR_EXTRACT}/html_report" "${OUTPUT_DIR}"
else
  echo "ERROR: html_report/ not found in ${COVERAGE_ZIP}" >&2
  exit 1
fi

echo "Coverage report written to: ${OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# Optional justification processing.
# ---------------------------------------------------------------------------
if [[ -n "${JUSTIFICATION_YAML}" && -f "${JUSTIFICATION_YAML}" ]]; then
  echo ""
  echo "Running coverage justification processing..."

  JUSTIFICATION_DIR="${TMPDIR_EXTRACT}/justification_report"
  mkdir -p "${JUSTIFICATION_DIR}"

  if "${_JUSTIFY}" \
      --yaml "${JUSTIFICATION_YAML}" \
      --source-root "${BUILD_WORKSPACE_DIRECTORY}" \
      --output "${JUSTIFICATION_DIR}/manifest.json"; then

    "${_EFFECTIVE_COVERAGE}" \
        --html-dir "${OUTPUT_DIR}" \
        --manifest "${JUSTIFICATION_DIR}/manifest.json" \
        --output "${JUSTIFICATION_DIR}/report.json"
  fi

  if [[ -f "${JUSTIFICATION_DIR}/summary.txt" ]]; then
    echo ""
    cat "${JUSTIFICATION_DIR}/summary.txt"

    EFFECTIVE_PCT=$(grep -oP 'Effective line coverage:\s+\K[0-9.]+' \
      "${JUSTIFICATION_DIR}/summary.txt" 2>/dev/null || echo "0")

    THRESHOLD="${COVERAGE_THRESHOLD:-100}"
    if awk "BEGIN {exit (${EFFECTIVE_PCT} >= ${THRESHOLD}) ? 0 : 1}"; then
      :
    else
      echo "WARNING: Effective coverage ${EFFECTIVE_PCT}% is below threshold ${THRESHOLD}%" >&2
    fi
  fi
elif [[ -n "${JUSTIFICATION_YAML}" ]]; then
  echo "INFO: --yaml ${JUSTIFICATION_YAML} not found, skipping justification processing."
else
  echo "INFO: No --yaml provided, skipping justification processing."
fi

# ---------------------------------------------------------------------------
# Optional CI archive.
# ---------------------------------------------------------------------------
if [[ -n "${ARCHIVE_NAME}" ]]; then
  mkdir -p artifacts

  if [[ -d "${JUNIT_GLOB}" ]]; then
    find "${JUNIT_GLOB}" -name 'test.xml' -exec cp --parents {} artifacts/ \; 2>/dev/null || true
  fi

  cp -r "${OUTPUT_DIR}" artifacts/

  if [[ -f "${TMPDIR_EXTRACT}/lcov_report/lcov.dat" ]]; then
    cp "${TMPDIR_EXTRACT}/lcov_report/lcov.dat" artifacts/coverage_report.dat
  fi

  zip -r "${ARCHIVE_NAME}.zip" artifacts/
  rm -rf artifacts/
  echo "Coverage archive written to: ${ARCHIVE_NAME}.zip"
fi
