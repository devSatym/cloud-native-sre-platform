#!/usr/bin/env bash
# Capture a timestamp-aligned non-sensitive evidence set after a live experiment.

set -euo pipefail

RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_ID="$RUN_ID" "$SCRIPT_DIR/capture-cluster-state.sh"
RUN_ID="$RUN_ID" "$SCRIPT_DIR/capture-hpa.sh"
RUN_ID="$RUN_ID" "$SCRIPT_DIR/capture-envoy.sh"
RUN_ID="$RUN_ID" "$SCRIPT_DIR/capture-slo.sh"
