#!/usr/bin/env bash
# Capture HPA state before, during, or after a k6 scaling run.

set -euo pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-docs/evidence/hpa}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${EVIDENCE_ROOT}/${RUN_ID}"

mkdir -p "$OUTPUT_DIR"

date -u +%Y-%m-%dT%H:%M:%SZ >"$OUTPUT_DIR/captured-at-utc.txt"
kubectl get hpa -n "$NAMESPACE" -o wide >"$OUTPUT_DIR/hpa.txt"
kubectl get deployment "${HELM_RELEASE_NAME}-api" -n "$NAMESPACE" -o wide \
  >"$OUTPUT_DIR/api-deployment.txt"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=api,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" \
  -o wide >"$OUTPUT_DIR/api-pods.txt"

if kubectl top pods -n "$NAMESPACE" \
  -l "app.kubernetes.io/name=api,app.kubernetes.io/instance=${HELM_RELEASE_NAME}" \
  >"$OUTPUT_DIR/api-top.txt" 2>"$OUTPUT_DIR/api-top.stderr"; then
  rm -f "$OUTPUT_DIR/api-top.stderr"
else
  printf '%s\n' 'kubectl top pods failed; inspect api-top.stderr. This is not HPA validation.' \
    >"$OUTPUT_DIR/README.txt"
fi

printf 'HPA state captured in %s\n' "$OUTPUT_DIR"
