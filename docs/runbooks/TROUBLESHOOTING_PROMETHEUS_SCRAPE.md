# Runbook: Prometheus cannot scrape API metrics

**Status:** Current procedure — not yet validated against a live GKE cluster.
**Severity:** P2 (observability degradation).
**Scope:** The Helm-managed API `ServiceMonitor`, Redis-backed API readiness, and
the Prometheus Operator target that should scrape `/metrics`.

## Safety and context

Set the target explicitly before inspecting it. These defaults are conventions,
not evidence that a matching cluster exists.

```bash
export NAMESPACE="${NAMESPACE:-sre-platform}"
export RELEASE="${RELEASE:-cloud-native-sre-platform}"
export MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
export PROMETHEUS_RELEASE="${PROMETHEUS_RELEASE:-kube-prometheus-stack}"
kubectl config current-context
kubectl get namespace "$NAMESPACE" "$MONITORING_NAMESPACE"
```

Do not restart, scale, or patch a workload until the evidence below identifies a
specific cause. Save redacted results under [`../evidence/observability/`](../evidence/observability/)
when performing a real investigation.

## Diagnose

### 1. Confirm the release and discovery objects exist

```bash
kubectl -n "$NAMESPACE" get deploy,svc,endpointslice
kubectl -n "$MONITORING_NAMESPACE" get servicemonitor "${RELEASE}-api" -o yaml
kubectl -n "$MONITORING_NAMESPACE" get prometheusrule "${RELEASE}-sre-rules" -o yaml
kubectl -n "$MONITORING_NAMESPACE" get prometheus
```

The app chart labels ServiceMonitors and PrometheusRules with
`release=${PROMETHEUS_RELEASE}`. The default matches
`scripts/deploy-observability.sh`; if a different Prometheus release was installed,
the application chart must be deployed with the same `PROMETHEUS_RELEASE` value.

### 2. Confirm API readiness and endpoints

The API liveness endpoint is intentionally independent of Redis. Readiness checks
Redis because it is required for the fail-closed rate limiter, so a ready endpoint
failure is a useful dependency signal.

```bash
kubectl -n "$NAMESPACE" get pods \
  -l "app.kubernetes.io/name=api,app.kubernetes.io/instance=${RELEASE}" -o wide
kubectl -n "$NAMESPACE" get endpointslice \
  -l "kubernetes.io/service-name=${RELEASE}-api" -o yaml
kubectl -n "$NAMESPACE" logs deploy/"${RELEASE}-api" --tail=100
kubectl -n "$NAMESPACE" logs deploy/"${RELEASE}-redis" --tail=100
```

If the API is not Ready, inspect DNS, the Redis Service/Endpoints, and the applied
NetworkPolicies before changing the ServiceMonitor:

```bash
kubectl -n "$NAMESPACE" get svc "${RELEASE}-redis"
kubectl -n "$NAMESPACE" describe networkpolicy "${RELEASE}-api-traffic"
kubectl -n "$NAMESPACE" describe networkpolicy "${RELEASE}-redis-traffic"
```

### 3. Inspect the Prometheus target and metric contract

Port-forward the actual Prometheus Service name if it differs from the default:

```bash
kubectl -n "$MONITORING_NAMESPACE" port-forward \
  "service/${PROMETHEUS_RELEASE}-prometheus" 9090:9090
```

In another terminal, query the target and canonical user-facing metrics:

```bash
curl -fsS --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode "query=up{namespace=\"${NAMESPACE}\",service=\"${RELEASE}-api\"}"

curl -fsS --get http://127.0.0.1:9090/api/v1/query \
  --data-urlencode "query=sre_api_user_requests_total{namespace=\"${NAMESPACE}\"}"
```

An empty target result can mean no discovery, no ready endpoints, a selector-label
mismatch, or network-policy connectivity. A target with value `0` is a scrape
failure; inspect the target's last error in the Prometheus UI and correlate it with
API/Redis logs.

## Corrective actions

1. Correct the smallest demonstrated cause in Helm values or application
   configuration; do not patch a Helm-managed object imperatively.
2. When observability is intentionally enabled, deploy the application with a
   matching namespace and Prometheus release label:

   ```bash
   MONITORING_ENABLED=true \
   MONITORING_NAMESPACE="$MONITORING_NAMESPACE" \
   PROMETHEUS_RELEASE="$PROMETHEUS_RELEASE" \
   ./scripts/deploy.sh
   ```

   `deploy.sh` still requires immutable application image coordinates for a
   non-development deployment.
3. Wait for the rollout, then repeat the target and metric queries. Do not call the
   issue resolved merely because the `ServiceMonitor` object exists.

## Expected validation evidence

Capture the applied ServiceMonitor, selector labels, endpoint state, Prometheus
target status, metric query, context, namespace, release, and revision. Mark this
procedure validated only after a real target reports healthy and the result is saved
under [`../evidence/observability/`](../evidence/observability/).

## Related current configuration

- [ServiceMonitors](../../deploy/helm/templates/servicemonitors.yaml)
- [Prometheus rules](../../deploy/helm/templates/prometheus-rules.yaml)
- [NetworkPolicies](../../deploy/helm/templates/networkpolicies.yaml)
- [SLO metric contract](../sre/slo-and-error-budget.md)
- [Live validation script](../../scripts/validate.sh)
