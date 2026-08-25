# Runbook: Application observability targets are missing or unhealthy

**Status:** Current procedure — no live GKE target result is committed yet.
**Severity:** P2 (observability degradation).
**Scope:** API, Payments, and Envoy ServiceMonitors; the app PrometheusRule;
Prometheus discovery; Grafana dashboard provisioning; and Loki availability.

## What this checks

The current GKE path installs the application chart and the observability stack
separately. The application release creates ServiceMonitors when
`monitoring.enabled=true` and a PrometheusRule when
`monitoring.prometheusRule.enabled=true`; the Prometheus Operator must already have
its CRDs installed. Grafana dashboard ConfigMaps are labeled for the dashboard
sidecar.

This is a diagnostic procedure, not proof that any target has previously worked.

## Establish context

```bash
export NAMESPACE="${NAMESPACE:-sre-platform}"
export RELEASE="${RELEASE:-cloud-native-sre-platform}"
export MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
export PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"

kubectl config current-context
kubectl get namespace "$NAMESPACE" "$MONITORING_NAMESPACE"
kubectl get crd servicemonitors.monitoring.coreos.com prometheusrules.monitoring.coreos.com
```

## Diagnose in order

### 1. Verify observability workloads

```bash
kubectl -n "$MONITORING_NAMESPACE" get pods
kubectl -n "$MONITORING_NAMESPACE" get svc
kubectl -n "$MONITORING_NAMESPACE" get prometheus
```

Identify any non-Running Prometheus, Grafana, Loki, or Promtail pod before
investigating the application. Read events and logs for the exact workload rather
than assuming a chart name or selector.

### 2. Verify app discovery objects and selector labels

```bash
kubectl -n "$MONITORING_NAMESPACE" get servicemonitor \
  "${RELEASE}-api" "${RELEASE}-payments" "${RELEASE}-envoy" -o yaml
kubectl -n "$MONITORING_NAMESPACE" get prometheusrule "${RELEASE}-sre-rules" -o yaml
kubectl -n "$NAMESPACE" get configmap -l grafana_dashboard=1
```

The `release` label on both ServiceMonitors and PrometheusRules must equal the
Prometheus Helm release that owns the selector. The supplied defaults are
`kube-prometheus-stack` in namespace `monitoring`. If the stack was installed with
different values, reconcile the application through `scripts/deploy.sh` with
matching `MONITORING_NAMESPACE` and `PROMETHEUS_RELEASE`; do not hand-edit the
discovery objects.

### 3. Verify application endpoints and NetworkPolicy paths

```bash
for service in api payments envoy; do
  kubectl -n "$NAMESPACE" get endpointslice \
    -l "kubernetes.io/service-name=${RELEASE}-${service}" -o wide
done

kubectl -n "$NAMESPACE" get networkpolicy
kubectl -n "$NAMESPACE" describe networkpolicy "${RELEASE}-api-traffic"
kubectl -n "$NAMESPACE" describe networkpolicy "${RELEASE}-payments-traffic"
kubectl -n "$NAMESPACE" describe networkpolicy "${RELEASE}-envoy-traffic"
```

The app NetworkPolicies allow the selected monitoring namespace to scrape API and
Payments on their HTTP ports and Envoy on its admin port. If a different monitoring
namespace is used, the Helm values must update both the chart monitoring namespace
and the NetworkPolicy monitoring namespace together.

### 4. Query Prometheus rather than relying on Kubernetes object existence

```bash
kubectl -n "$MONITORING_NAMESPACE" port-forward \
  "service/${PROMETHEUS_RELEASE}-prometheus" 9090:9090
```

Then use the Prometheus UI or API to inspect current app targets:

```bash
curl -fsS --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode "query=up{namespace=\"${NAMESPACE}\"}"

curl -fsS --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode "query=sre_api_user_requests_total{namespace=\"${NAMESPACE}\"}"
```

Record target labels, values, and scrape errors. Do not infer user-facing health
from an `up` series alone; use the canonical `/pay` metrics and SLO queries for the
caller path.

## Corrective path and verification

1. Repair the evidenced prerequisite (CRD, selector label, endpoint/readiness,
   namespace alignment, or NetworkPolicy) in version-controlled values/templates.
2. Reconcile with Helm using immutable images. If observability is enabled, pass
   the matching monitoring parameters to `scripts/deploy.sh`.
3. Run [`scripts/validate.sh`](../../scripts/validate.sh) with the same namespace,
   release, and monitoring variables. It returns non-zero if an expected target,
   rule, dashboard pod, Loki check, endpoint, or rollout is missing.
4. Save the real target output, rule result, and dashboard/Loki observation under
   [`../evidence/observability/`](../evidence/observability/) with UTC context.

## Related current configuration

- [Application ServiceMonitors](../../deploy/helm/templates/servicemonitors.yaml)
- [SLO and alert rules](../../deploy/helm/templates/prometheus-rules.yaml)
- [SRE dashboard](../../deploy/helm/dashboards/sre-service-overview.json)
- [Prometheus values](../../deploy/prometheus/values.yaml)
- [Loki values](../../deploy/loki/values.yaml)
- [SLO design](../sre/slo-and-error-budget.md)
