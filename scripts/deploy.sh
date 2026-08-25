#!/usr/bin/env bash
# Deploy the application Helm release with immutable application images.

set -euo pipefail

NAMESPACE="${NAMESPACE:-sre-platform}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-cloud-native-sre-platform}"
VALUES_FILE="${VALUES_FILE:-deploy/helm/values.yaml}"
API_IMAGE_REPOSITORY="${API_IMAGE_REPOSITORY:-}"
API_IMAGE_TAG="${API_IMAGE_TAG:-}"
PAYMENTS_IMAGE_REPOSITORY="${PAYMENTS_IMAGE_REPOSITORY:-}"
PAYMENTS_IMAGE_TAG="${PAYMENTS_IMAGE_TAG:-}"
MONITORING_ENABLED="${MONITORING_ENABLED:-false}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"

args=(upgrade --install "$HELM_RELEASE_NAME" deploy/helm --namespace "$NAMESPACE" --create-namespace --values "$VALUES_FILE")

if [[ "$VALUES_FILE" == *values-dev* ]]; then
  : # Local image coordinates are intentionally supplied by the dev values file.
else
  for required in API_IMAGE_REPOSITORY API_IMAGE_TAG PAYMENTS_IMAGE_REPOSITORY PAYMENTS_IMAGE_TAG; do
    if [[ -z "${!required}" ]]; then
      echo "ERROR: ${required} is required for a non-development deployment." >&2
      exit 2
    fi
  done
  args+=(
    --set-string "api.image.repository=${API_IMAGE_REPOSITORY}"
    --set-string "api.image.tag=${API_IMAGE_TAG}"
    --set-string "payments.image.repository=${PAYMENTS_IMAGE_REPOSITORY}"
    --set-string "payments.image.tag=${PAYMENTS_IMAGE_TAG}"
  )
fi

if [[ "$MONITORING_ENABLED" == "true" ]]; then
  args+=(
    --set monitoring.enabled=true
    --set monitoring.prometheusRule.enabled=true
    --set-string "monitoring.namespace=${MONITORING_NAMESPACE}"
    --set-string "monitoring.releaseLabel=${PROMETHEUS_RELEASE}"
    --set-string "networkPolicy.monitoringNamespace=${MONITORING_NAMESPACE}"
  )
fi

helm "${args[@]}"
kubectl rollout status -n "$NAMESPACE" "deployment/${HELM_RELEASE_NAME}-api" --timeout=180s
kubectl rollout status -n "$NAMESPACE" "deployment/${HELM_RELEASE_NAME}-payments" --timeout=180s
kubectl rollout status -n "$NAMESPACE" "deployment/${HELM_RELEASE_NAME}-envoy" --timeout=180s

printf 'Application release %s is deployed in namespace %s.\n' "$HELM_RELEASE_NAME" "$NAMESPACE"
