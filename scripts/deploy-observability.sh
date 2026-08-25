#!/usr/bin/env bash
# Install the intentionally small Prometheus/Grafana/Loki stack required by the app chart.

set -euo pipefail

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"
LOKI_RELEASE="${LOKI_RELEASE:-loki}"
PROMETHEUS_CHART_VERSION="${PROMETHEUS_CHART_VERSION:-88.5.4}"
LOKI_CHART_VERSION="${LOKI_CHART_VERSION:-2.10.3}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install "$PROMETHEUS_RELEASE" prometheus-community/kube-prometheus-stack \
  --version "$PROMETHEUS_CHART_VERSION" \
  --namespace "$MONITORING_NAMESPACE" --create-namespace \
  --values deploy/prometheus/values.yaml \
  --set-string "grafana.additionalDataSources[0].url=http://${LOKI_RELEASE}.${MONITORING_NAMESPACE}.svc.cluster.local:3100"

helm upgrade --install "$LOKI_RELEASE" grafana/loki-stack \
  --version "$LOKI_CHART_VERSION" \
  --namespace "$MONITORING_NAMESPACE" \
  --values deploy/loki/values.yaml

printf 'Observability releases installed. Deploy the application with MONITORING_ENABLED=true, MONITORING_NAMESPACE=%s, and PROMETHEUS_RELEASE=%s next.\n' \
  "$MONITORING_NAMESPACE" "$PROMETHEUS_RELEASE"
