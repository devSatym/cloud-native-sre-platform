#!/usr/bin/env bash
# Capture SLO query results through a temporary local Prometheus port-forward.

set -euo pipefail

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"
PROMETHEUS_SERVICE="${PROMETHEUS_SERVICE:-${PROMETHEUS_RELEASE}-prometheus}"
NAMESPACE="${NAMESPACE:-sre-platform}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-docs/evidence/slo}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${EVIDENCE_ROOT}/${RUN_ID}"
LOCAL_PORT="${PROMETHEUS_LOCAL_PORT:-19090}"
PID=""

cleanup() {
  if [[ -n "$PID" ]]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

query() {
  local name="$1"
  local expression="$2"
  curl --fail --silent --get "http://127.0.0.1:${LOCAL_PORT}/api/v1/query" \
    --data-urlencode "query=${expression}" >"$OUTPUT_DIR/${name}.json"
}

mkdir -p "$OUTPUT_DIR"
kubectl port-forward -n "$MONITORING_NAMESPACE" "service/${PROMETHEUS_SERVICE}" \
  "${LOCAL_PORT}:9090" >"$OUTPUT_DIR/port-forward.log" 2>&1 &
PID=$!

for _ in $(seq 1 20); do
  if curl --fail --silent "http://127.0.0.1:${LOCAL_PORT}/-/ready" >/dev/null; then
    break
  fi
  sleep 1
done

query availability-sli "sre:api_availability:ratio_30d{namespace=\"${NAMESPACE}\"}"
query latency-sli "sre:api_latency:ratio_30d{namespace=\"${NAMESPACE}\"}"
query error-budget-remaining "sre:api_error_budget_remaining:ratio{namespace=\"${NAMESPACE}\"}"
query error-budget-consumed "sre:api_error_budget_consumed:ratio{namespace=\"${NAMESPACE}\"}"
query fast-burn "sre:api_error_budget_burn_rate:5m{namespace=\"${NAMESPACE}\"}"
query slow-burn "sre:api_error_budget_burn_rate:1h{namespace=\"${NAMESPACE}\"}"

printf 'SLO query results captured in %s\n' "$OUTPUT_DIR"
