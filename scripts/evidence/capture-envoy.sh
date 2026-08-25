#!/usr/bin/env bash
# Capture Envoy resilience counters without storing credentials.

set -euo pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-docs/evidence/resilience}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${EVIDENCE_ROOT}/${RUN_ID}"
LOCAL_PORT="${ENVOY_ADMIN_LOCAL_PORT:-19901}"
PID=""

cleanup() {
  if [[ -n "$PID" ]]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
kubectl port-forward -n "$NAMESPACE" "service/${HELM_RELEASE_NAME}-envoy" \
  "${LOCAL_PORT}:9901" >"$OUTPUT_DIR/port-forward.log" 2>&1 &
PID=$!

for _ in $(seq 1 20); do
  if curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/ready" >/dev/null; then
    break
  fi
  sleep 1
done

curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/stats?filter=upstream_rq_retry" \
  >"$OUTPUT_DIR/retry-counters.txt"
curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/stats?filter=outlier_detection" \
  >"$OUTPUT_DIR/outlier-counters.txt"
curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/stats?filter=overflow" \
  >"$OUTPUT_DIR/bulkhead-counters.txt"
curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/stats?filter=timeout" \
  >"$OUTPUT_DIR/timeout-counters.txt"

printf 'Envoy counters captured in %s\n' "$OUTPUT_DIR"
