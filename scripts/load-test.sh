#!/usr/bin/env bash
# Run one focused k6 test. Results are evidence only when the command is actually run.

set -euo pipefail

TEST_NAME="${1:-baseline}"
TEST_FILE="tests/load/${TEST_NAME}.js"

if ! command -v k6 >/dev/null 2>&1; then
  echo "ERROR: k6 is required. Install it, then run this command again." >&2
  exit 2
fi
if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: unknown load test ${TEST_NAME}; expected ${TEST_FILE}" >&2
  exit 2
fi

k6 run "$TEST_FILE"
