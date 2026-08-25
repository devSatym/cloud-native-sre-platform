#!/usr/bin/env bash
# Capture non-sensitive cluster state for an evidence run.

set -euo pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-docs/evidence/gke}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${EVIDENCE_ROOT}/${RUN_ID}"

mkdir -p "$OUTPUT_DIR"

kubectl config current-context >"$OUTPUT_DIR/context.txt"
kubectl get nodes -o wide >"$OUTPUT_DIR/nodes.txt"
kubectl get namespace "$NAMESPACE" -o yaml >"$OUTPUT_DIR/namespace.yaml"
kubectl get deployments,pods,services,endpointslices -n "$NAMESPACE" -o wide \
  >"$OUTPUT_DIR/workloads.txt"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp >"$OUTPUT_DIR/events.txt"
helm status "$HELM_RELEASE_NAME" -n "$NAMESPACE" >"$OUTPUT_DIR/helm-status.txt"

printf 'Cluster state captured in %s\n' "$OUTPUT_DIR"
