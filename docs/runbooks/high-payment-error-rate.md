# Runbook: High User-Facing Payment Error Rate

**Status:** Draft — procedure prepared; end-to-end incident validation is pending.
**Severity:** P1 (high) unless the payment path is wholly unavailable, then assess P0.
**Scope:** API `POST /pay`, its Payments dependency, and the proxy path between them.

## Trigger and user impact

Use this runbook when the deployed user-facing error-rate or SLO burn alert fires.
The intended alert names are `HighErrorRate` and/or `SLOBudgetFastBurn`; confirm the
actual rule name, labels, and firing state in the deployed Prometheus/Alertmanager
before relying on those names. This document does not prove that either alert is
configured or has fired.

Users may see failed payments, typically an API `503` when Payments returns an error
or is unavailable, or `504` when the API times out waiting for Payments. Record the
observed status mix rather than assuming it.

## Safety and evidence first

These examples use `sre-platform` and `cloud-native-sre-platform` as conventions.
They do not assert that a cluster, namespace, or Helm release with those names exists.
Set the variables to the target that was selected for the incident, and record the
context before changing anything.

```bash
export NAMESPACE="${NAMESPACE:-sre-platform}"
export RELEASE="${RELEASE:-cloud-native-sre-platform}"
export API_SELECTOR="app.kubernetes.io/name=api,app.kubernetes.io/instance=${RELEASE}"
export PAYMENTS_SELECTOR="app.kubernetes.io/name=payments,app.kubernetes.io/instance=${RELEASE}"
export ENVOY_SELECTOR="app.kubernetes.io/name=envoy,app.kubernetes.io/instance=${RELEASE}"
kubectl config current-context
kubectl get namespace "$NAMESPACE"
kubectl -n "$NAMESPACE" get deploy,pod,svc
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp | tail -n 50
```

Do not paste credentials, request bodies containing sensitive data, or raw tokens
into evidence. Save redacted, timestamped baseline output under
[`../evidence/incident/`](../evidence/incident/) before mitigation when practical.

## Initial checks

### 1. Confirm the user-facing SLI is degraded

In Prometheus, first verify that the canonical `/pay` metric is present and that its
`status_class` label has the expected values. Then evaluate the candidate queries for
the observed incident window:

```promql
sum(rate(sre_api_user_requests_total{namespace="$NAMESPACE",status_class="5xx"}[5m]))
/
clamp_min(sum(rate(sre_api_user_requests_total{namespace="$NAMESPACE"}[5m])), 0.001)
```

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(sre_api_user_request_duration_seconds_bucket{namespace="$NAMESPACE"}[5m]))
)
```

Record the query, selected time range, and result. Health, readiness, and metrics
scrape traffic must not be used to decide whether users are affected.

### 2. Identify the failing layer

```bash
kubectl -n "$NAMESPACE" get pods -l "$API_SELECTOR" -o wide
kubectl -n "$NAMESPACE" get pods -l "$PAYMENTS_SELECTOR" -o wide
kubectl -n "$NAMESPACE" get endpointslice -l kubernetes.io/service-name
kubectl -n "$NAMESPACE" logs -l "$API_SELECTOR" --all-containers --since=10m
kubectl -n "$NAMESPACE" logs -l "$PAYMENTS_SELECTOR" --all-containers --since=10m
```

Use Grafana to correlate the error/latency change with traffic, saturation, and
dependency health. In Loki, constrain queries to the incident window and the API or
Payments labels actually present in the deployment; record the query as well as any
relevant redacted result.

### 3. Inspect Envoy only after identifying its deployed pod

```bash
ENVOY_POD="$(kubectl -n "$NAMESPACE" get pods -l "$ENVOY_SELECTOR" \
  -o jsonpath='{.items[0].metadata.name}')"
printf '%s\n' "$ENVOY_POD"
```

If a pod name was returned, port-forward its admin interface in a separate terminal:

```bash
kubectl -n "$NAMESPACE" port-forward "pod/$ENVOY_POD" 9901:9901
```

Then inspect the relevant clusters from a local terminal:

```bash
curl -fsS 'http://127.0.0.1:9901/stats?filter=payments_service|api_service'
```

Look for upstream response classes, retry counts, pending-request or connection
overflow counters, and outlier ejections. Counter movement is diagnostic evidence,
not proof by itself that the user-facing SLI is correct.

## Diagnosis guide

| Observation | Likely area | Next check |
| --- | --- | --- |
| `/pay` `5xx` rises with Payments `5xx` | Controlled failure or Payments application failure | Payments deployment revision, environment, logs, and recent changes. |
| API `503`/`504` rises while Payments is not ready or has no endpoints | Dependency availability, DNS, network policy, or timeout path | EndpointSlices, readiness, events, DNS/connectivity, and proxy upstream state. |
| p95 latency rises before errors | Slow dependency, saturation, retry amplification, or timeout tuning | Payments latency/logs, API saturation, Envoy retries/timeouts, and HPA state. |
| Proxy counters show failure but `sre_api_user_*` does not degrade | Signal mismatch or traffic-path gap | Verify the request path and metric instrumentation before declaring the alerting blind spot fixed. |

Do not infer a root cause from one graph. Correlate the user-facing SLI with logs,
Kubernetes state, and the exact fault/change history.

## Mitigation

Choose the smallest reversible action supported by evidence.

### Controlled fault experiment

If the incident was intentionally created with the repository fault helper, first
confirm that the helper targets the selected namespace and deployment. Then remove
the injected fault and wait for the Payments rollout:

```bash
NAMESPACE="$NAMESPACE" ./scripts/fault-inject.sh cleanup
kubectl -n "$NAMESPACE" get deploy -l "$PAYMENTS_SELECTOR"
```

The helper is not a substitute for checking its current implementation. If the
experiment used a Helm values change, restore the known-good Helm revision only after
reviewing the release history:

```bash
helm -n "$NAMESPACE" history "$RELEASE"
# After selecting a known-good revision deliberately:
# helm -n "$NAMESPACE" rollback "$RELEASE" <revision>
```

### Unplanned failure

- If a recent, identified deployment caused the regression, use the approved Helm
  rollback path after reviewing release history.
- If the fault is isolated to an unhealthy dependency pod, let the workload controller
  and readiness probes reconcile it first; do not use direct pod deletion as a PDB
  test or as a default remedy.
- If a NetworkPolicy, service endpoint, or configuration error is indicated, make the
  smallest reviewed configuration correction and reconcile it through Helm/GitOps.
- Escalate rather than widening timeouts, disabling rate limits, or increasing
  replicas blindly. Those actions can mask the signal or increase blast radius.

## Verify recovery

1. Confirm API and Payments pods are Ready and the expected EndpointSlices contain
   ready endpoints.
2. Re-run the availability and latency queries over a post-mitigation window; allow
   for the configured query/alert window rather than expecting an instant reset.
3. Confirm the intended alert resolves through the normal alerting path, not merely
   in a local Prometheus expression.
4. Make a non-sensitive `/pay` request through the same user-facing route used by
   the test, if authorized for the environment.
5. Capture cleanup/recovery evidence and link it from the postmortem.

**Success criteria — TO BE VALIDATED:** the user-facing error ratio returns to its
normal observed range, dependency pods/endpoints are healthy, no fault remains, and
the alert resolves after its configured evaluation period.

## Escalation

Escalate immediately if payment processing is unavailable, failures continue after a
known-safe rollback/cleanup, data integrity is in doubt, or mitigation requires a
change outside the on-call engineer's authority. Include the alert, UTC timeline,
query results, relevant redacted logs, Kubernetes events, current revision, and
actions already taken.

## Evidence to capture

**TO BE CAPTURED DURING VALIDATION:** alert notification/state; Prometheus and
Grafana time ranges; Loki query and redacted result; Envoy counters; pod, endpoint,
and event snapshots; fault/mitigation command; recovery query; cluster/namespace/
release; and Git or image revision. Store real artifacts in
[`../evidence/incident/`](../evidence/incident/) and summarize them in the
[payment-degradation postmortem](../postmortems/payment-degradation.md).
