#!/usr/bin/env bash
# Backward-compatible cleanup entry point.

set -euo pipefail

exec "$(dirname "$0")/fault-inject.sh" cleanup
