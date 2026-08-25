#!/usr/bin/env bash
# Live-cluster validation. It returns non-zero on any failed check and sends one
# non-sensitive, in-memory payment to verify the API-to-Payments user path.

set -u -o pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"
PROMETHEUS_SERVICE="${PROMETHEUS_SERVICE:-${PROMETHEUS_RELEASE}-prometheus}"
PROMETHEUS_PORT="${PROMETHEUS_LOCAL_PORT:-19090}"
ENVOY_PORT="${ENVOY_LOCAL_PORT:-18080}"
LOKI_RELEASE="${LOKI_RELEASE:-loki}"
FAILURES=0
PROMETHEUS_PID=""
ENVOY_PID=""

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

cleanup() {
  for pid in "$PROMETHEUS_PID" "$ENVOY_PID"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

wait_for_http() {
  local url="$1"
  for _ in $(seq 1 20); do
    if curl --fail --silent "$url" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

check_rollout() {
  local deployment="$1"
  if kubectl rollout status -n "$NAMESPACE" "deployment/${deployment}" --timeout=120s; then
    pass "deployment/${deployment} is Available"
  else
    fail "deployment/${deployment} is not Available"
  fi
}

if kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
  pass 'cluster is reachable'
else
  fail 'cluster is unreachable'
  exit 1
fi

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  pass "namespace/${NAMESPACE} exists"
else
  fail "namespace/${NAMESPACE} is missing"
  exit 1
fi

if kubectl get namespace "$MONITORING_NAMESPACE" >/dev/null 2>&1; then
  pass "namespace/${MONITORING_NAMESPACE} exists"
else
  fail "namespace/${MONITORING_NAMESPACE} is missing"
  exit 1
fi

for deployment in "${HELM_RELEASE_NAME}-api" "${HELM_RELEASE_NAME}-payments" \
  "${HELM_RELEASE_NAME}-envoy" "${HELM_RELEASE_NAME}-redis"; do
  check_rollout "$deployment"
done

for service in "${HELM_RELEASE_NAME}-api" "${HELM_RELEASE_NAME}-payments" \
  "${HELM_RELEASE_NAME}-envoy" "${HELM_RELEASE_NAME}-redis"; do
  if kubectl get endpointslice -n "$NAMESPACE" \
    -l "kubernetes.io/service-name=${service}" -o jsonpath='{.items[0].endpoints[0].addresses[0]}' \
    | grep -q .; then
    pass "service/${service} has endpoints"
  else
    fail "service/${service} has no endpoints"
  fi
done

for resource in "hpa/${HELM_RELEASE_NAME}-api-hpa" \
  "pdb/${HELM_RELEASE_NAME}-api-pdb" \
  "pdb/${HELM_RELEASE_NAME}-payments-pdb"; do
  if kubectl get -n "$NAMESPACE" "$resource" >/dev/null 2>&1; then
    pass "$resource exists"
  else
    fail "$resource is missing"
  fi
done

if kubectl get -n "$MONITORING_NAMESPACE" \
  "prometheusrule/${HELM_RELEASE_NAME}-sre-rules" >/dev/null 2>&1; then
  pass 'SLO and alert rules are installed'
else
  fail 'SLO and alert rules are missing'
fi

if kubectl get pods -n "$MONITORING_NAMESPACE" -l app.kubernetes.io/name=grafana \
  --field-selector=status.phase=Running -o name | grep -q .; then
  pass 'Grafana has a Running pod'
else
  fail 'Grafana has no Running pod'
fi

if kubectl get service -n "$MONITORING_NAMESPACE" "$LOKI_RELEASE" >/dev/null 2>&1 \
  && kubectl get endpointslice -n "$MONITORING_NAMESPACE" \
    -l "kubernetes.io/service-name=${LOKI_RELEASE}" \
    -o jsonpath='{.items[0].endpoints[0].addresses[0]}' | grep -q .; then
  pass 'Loki service has a ready endpoint'
else
  fail 'Loki service has no ready endpoint'
fi

kubectl port-forward -n "$NAMESPACE" "service/${HELM_RELEASE_NAME}-envoy" \
  "${ENVOY_PORT}:80" >/tmp/cloud-native-sre-envoy-validate.log 2>&1 &
ENVOY_PID=$!
if wait_for_http "http://127.0.0.1:${ENVOY_PORT}/healthz"; then
  pass 'API responds through Envoy'
else
  fail 'API does not respond through Envoy'
fi

VALIDATION_TENANT="validation-${RANDOM}-${RANDOM}"
if curl --fail --silent --show-error \
  --request POST "http://127.0.0.1:${ENVOY_PORT}/api/pay" \
  --header 'Content-Type: application/json' \
  --header "X-Tenant: ${VALIDATION_TENANT}" \
  --data "{\"amount\":1,\"currency\":\"USD\",\"tenant_id\":\"${VALIDATION_TENANT}\"}" \
  | jq -e '.status == "completed" and (.payment_id | type == "string")' >/dev/null; then
  pass 'API-to-Payments user path succeeds through Envoy'
else
  fail 'API-to-Payments user path fails through Envoy'
fi

kubectl port-forward -n "$MONITORING_NAMESPACE" "service/${PROMETHEUS_SERVICE}" \
  "${PROMETHEUS_PORT}:9090" >/tmp/cloud-native-sre-prometheus-validate.log 2>&1 &
PROMETHEUS_PID=$!
if wait_for_http "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready"; then
  if curl --fail --silent --get "http://127.0.0.1:${PROMETHEUS_PORT}/api/v1/query" \
    --data-urlencode "query=up{namespace=\"${NAMESPACE}\",service=~\"${HELM_RELEASE_NAME}-(api|payments|envoy)\"}" \
    | jq -e '.status == "success" and (.data.result | length > 0) and all(.[]; .value[1] == "1")' \
      >/dev/null; then
    pass 'Prometheus application targets are healthy'
  else
    fail 'Prometheus application targets are not all healthy'
  fi
else
  fail 'Prometheus is not reachable'
fi

if (( FAILURES > 0 )); then
  printf '%s validation check(s) failed.\n' "$FAILURES" >&2
  exit 1
fi

printf 'All live validation checks passed. Save fresh evidence before making a completion claim.\n'
