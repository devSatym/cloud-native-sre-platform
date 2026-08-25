#!/usr/bin/env bash
# Reversible fault injection for the Cloud-Native SRE Platform.

set -euo pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
PAYMENTS_DEPLOYMENT="${PAYMENTS_DEPLOYMENT:-${HELM_RELEASE_NAME}-payments}"
PAYMENTS_SELECTOR="app.kubernetes.io/name=payments,app.kubernetes.io/instance=${HELM_RELEASE_NAME}"
FAULT_DELAY="${FAULT_DELAY:-300ms}"
MODE="${1:-help}"

usage() {
  cat <<EOF
Usage: $0 [MODE]

Modes:
  latency    Add a reversible tc netem delay to every Payments pod
  failure    Set FAIL_MODE=1 so Payments returns HTTP 500
  slow       Set SLOW_MODE=1 so Payments delays each request for two seconds
  kill       Delete one Payments pod to demonstrate recovery (not a PDB test)
  cleanup    Remove flags and tc qdiscs, then wait for the rollout
  help       Show this help

Environment variables:
  NAMESPACE            Kubernetes namespace (default: sre-platform)
  HELM_RELEASE_NAME    Helm release name (default: cloud-native-sre-platform)
  PAYMENTS_DEPLOYMENT  Override the derived Deployment name
  FAULT_DELAY          netem delay (default: 300ms)

Before latency injection, deploy the explicit chaos values file so Payments has
the required NET_ADMIN capability. Always run cleanup or reconcile the Helm release
after an experiment. This script never substitutes for the PDB eviction runbook.
EOF
}

payments_pods() {
  kubectl get pods -n "$NAMESPACE" -l "$PAYMENTS_SELECTOR" -o name
}

require_payments_pods() {
  local pods
  pods="$(payments_pods)"
  if [[ -z "$pods" ]]; then
    echo "ERROR: no Payments pods match $PAYMENTS_SELECTOR in $NAMESPACE" >&2
    exit 1
  fi
  printf '%s\n' "$pods"
}

inject_latency() {
  echo "Injecting ${FAULT_DELAY} latency into Payments pods..."
  local pod
  while IFS= read -r pod; do
    echo "  -> $pod"
    if ! kubectl exec -n "$NAMESPACE" "$pod" -- which tc >/dev/null 2>&1; then
      echo "ERROR: tc is unavailable in $pod. Rebuild the Payments image with iproute2." >&2
      exit 1
    fi
    kubectl exec -n "$NAMESPACE" "$pod" -- \
      tc qdisc replace dev eth0 root netem delay "$FAULT_DELAY"
  done < <(require_payments_pods)

  echo "Latency injection applied. Capture Envoy counters and k6 output before cleanup."
}

set_fault_flag() {
  local flag="$1"
  echo "Setting ${flag}=1 on deployment/${PAYMENTS_DEPLOYMENT}..."
  kubectl set env -n "$NAMESPACE" "deployment/${PAYMENTS_DEPLOYMENT}" "${flag}=1"
  kubectl rollout status -n "$NAMESPACE" "deployment/${PAYMENTS_DEPLOYMENT}" --timeout=180s
  echo "${flag} is enabled. This mutates a Helm-managed workload; run cleanup and reconcile Helm."
}

kill_pod() {
  local pod
  pod="$(kubectl get pods -n "$NAMESPACE" -l "$PAYMENTS_SELECTOR" -o jsonpath='{.items[0].metadata.name}')"
  if [[ -z "$pod" ]]; then
    echo "ERROR: no Payments pod found in $NAMESPACE" >&2
    exit 1
  fi

  echo "Deleting pod/${pod}. Direct deletion demonstrates recovery only; it bypasses PDB eviction."
  kubectl delete pod -n "$NAMESPACE" "$pod"
}

cleanup() {
  echo "Removing fault flags from deployment/${PAYMENTS_DEPLOYMENT}..."
  kubectl set env -n "$NAMESPACE" "deployment/${PAYMENTS_DEPLOYMENT}" \
    FAIL_MODE- SLOW_MODE- 2>/dev/null || true

  local pod
  while IFS= read -r pod; do
    echo "  -> clearing tc state on $pod"
    kubectl exec -n "$NAMESPACE" "$pod" -- \
      tc qdisc del dev eth0 root 2>/dev/null || true
  done < <(payments_pods || true)

  kubectl rollout status -n "$NAMESPACE" "deployment/${PAYMENTS_DEPLOYMENT}" --timeout=180s
  echo "Cleanup completed. Re-run Helm upgrade with the non-chaos values to remove any elevated capability."
}

case "$MODE" in
  latency)
    inject_latency
    ;;
  failure)
    set_fault_flag FAIL_MODE
    ;;
  slow)
    set_fault_flag SLOW_MODE
    ;;
  kill)
    kill_pod
    ;;
  cleanup)
    cleanup
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "ERROR: unsupported fault mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac
