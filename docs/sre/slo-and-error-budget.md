# SLOs and Error Budgets

**Status:** SLO definition and canonical metric contract are documented. End-to-end
dashboard, recording-rule, and alert validation is **pending**.

This project deliberately has two primary SLOs. They describe the user-facing
`POST /pay` path, rather than health checks, readiness probes, or Prometheus scrapes.
The canonical API metrics are `sre_api_user_requests_total` and
`sre_api_user_request_duration_seconds`; both use a `status_class` label. Before
calling either SLO validated, verify the metric names, label values, and query results
in the deployed Prometheus instance.

## Service-level objectives

| SLO | Objective | Measurement window | Bad event |
| --- | --- | --- | --- |
| API availability | At least **99.5%** of user-facing `/pay` requests are served without a server error. | Proposed 30-day rolling window | A `5xx` response on the instrumented `/pay` path. `4xx` responses are treated as handled client/rate-limit outcomes unless this policy is deliberately changed. |
| API latency | At least **95%** of user-facing `/pay` requests complete in **500 ms or less**. | Proposed 30-day rolling window | A request whose measured duration is greater than 500 ms. |

The 30-day window is a project design choice, not evidence that Prometheus currently
retains 30 days of data. If retention is shorter, use recording rules or an SLO
calculation that preserves the required window before reporting a 30-day result.

## SLI definitions

The following expressions show the intended metric contract. They are not captured
results. Replace `$NAMESPACE` with the deployed application namespace and confirm
whether `status_class` values are represented as `2xx`, `4xx`, and `5xx` before
using the expressions unchanged.

### Availability SLI

```promql
sum(rate(sre_api_user_requests_total{namespace="$NAMESPACE",status_class!~"5xx"}[30d]))
/
sum(rate(sre_api_user_requests_total{namespace="$NAMESPACE"}[30d]))
```

This is the fraction of valid user-facing requests that did not produce a server
error. The instrumentation contract, not a path-label filter, excludes `/healthz`,
`/readyz`, and `/metrics`: the `sre_api_user_*` series must be emitted only for the
user-facing `/pay` path.

### Latency SLI

```promql
sum(rate(sre_api_user_request_duration_seconds_bucket{namespace="$NAMESPACE",le="0.5"}[30d]))
/
sum(rate(sre_api_user_request_duration_seconds_count{namespace="$NAMESPACE"}[30d]))
```

This is the fraction of instrumented `/pay` requests that completed within the
500 ms objective. A deployment must expose the histogram buckets before this
expression can be evaluated.

## Error budget

The availability target leaves a **0.5% error budget**:

```text
100% - 99.5% = 0.5%
```

For every 10,000 qualifying `/pay` requests in the window, up to 50 server-error
responses fit within the availability budget. This is not a target for failures; it
is the amount of unreliability the service can absorb while still meeting its stated
objective.

| Value | Meaning |
| --- | --- |
| SLO target | The reliability promise being measured: 99.5% availability. |
| Current SLI | The measured availability ratio for the selected window. |
| Budget consumed | Observed bad-event ratio divided by the allowed 0.5% bad-event ratio. |
| Budget remaining | The unconsumed portion of the 0.5% allowance. A negative calculated value means the budget has been exceeded; it must not be displayed as healthy by clamping it silently. |

The latency objective also has a 5% allowance for requests slower than 500 ms. It is
tracked as its own SLO budget, but it does not create a third primary SLO.

## Burn rate in plain language

Burn rate compares the current bad-event rate with the rate that would exhaust the
budget evenly across the SLO window. A burn rate of `1` spends the budget at the
planned pace; `10` spends it ten times faster. Short, high burn is useful for urgent
pages; longer, lower burn is useful for tickets or early warning. The exact alert
thresholds and windows must be read from the deployed alert rules, then validated
with real alert state and evidence.

## Validation checklist

Do not change the status above to **Validated** until all relevant checks have real,
timestamped evidence.

- [ ] Confirm `sre_api_user_requests_total` and
  `sre_api_user_request_duration_seconds` are scraped from the intended API target.
- [ ] Confirm their `status_class` values and that health, readiness, and metrics
  traffic do not enter the `sre_api_user_*` series.
- [ ] Run both SLI queries for a time window supported by retained data and record
  the exact queries/time range.
- [ ] Verify the dashboard exposes target, current SLI, budget consumed, and budget
  remaining without masking an exhausted budget.
- [ ] Exercise the controlled Payments failure, observe the user-facing `/pay`
  signal and the configured burn/error alert, remove the fault, and confirm recovery.
- [ ] Save redacted outputs in [`../evidence/slo/`](../evidence/slo/) and link them
  from the incident record when applicable.

**TO BE CAPTURED DURING VALIDATION:** metric discovery output, Prometheus query
results, dashboard evidence, alert state, test window, cluster/namespace/release,
and the Git or image revision.

## Interview summary

An SLI is the measured ratio, an SLO is the target for that ratio, and an error budget
is the allowed amount of failure implied by the target. In this project, the
availability SLI measures user-facing `/pay` responses rather than probe traffic, so
the alerting and budget reflect what callers experience.
