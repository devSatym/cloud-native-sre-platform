# Project Overview: Interview Talk Tracks

**Evidence note:** This page distinguishes repository configuration from demonstrated
operation. At the time it was written, the evidence ledger contains no end-to-end GKE
or incident capture, so use “configured” or “designed” unless a linked artifact proves
a result.

## 30 seconds

> Cloud-Native Reliability Engineering Platform is a small payments workload built to
> demonstrate SRE practices without hiding them behind enterprise-scale infrastructure.
> A FastAPI API serves the user-facing <code>/pay</code> path, calls a Payments service, and uses
> Redis for rate limiting. Envoy is the resilience boundary for proxy retries,
> timeouts, circuit-breaking limits, and outlier detection. Helm and Terraform define
> the Kubernetes/GKE path, while Prometheus, Grafana, and Loki are the observability
> stack. I defined two user-facing SLOs—availability and latency—and the project is
> structured around proving them with a controlled Payments incident, a runbook,
> evidence, and a postmortem. I describe anything without captured evidence as
> configured rather than validated.

## 2 minutes

### Problem and scope

I wanted a project that shows the operational side of a distributed service, not just
how to deploy containers. The intentionally small request path is:

~~~text
caller → Envoy → API POST /pay → Payments → response
                         └→ Redis rate-limit state
~~~

This makes a downstream failure easy to reason about: it can become user-visible
errors or latency at the API, appear in proxy/application signals, consume an error
budget, trigger an alert, and be handled with a documented recovery procedure.

### Reliability design

The configuration puts different protections at different layers:

- Kubernetes workload controls such as probes, HPA, and PDBs address readiness,
  capacity, and voluntary disruption.
- Envoy configuration is intended to bound downstream behavior with retries,
  per-try/route timeouts, circuit-breaker limits, and outlier detection.
- Redis-backed rate limiting protects the API from a single tenant consuming all
  request capacity.
- The user-facing SLI deliberately uses <code>sre_api_user_requests_total</code> and
  <code>sre_api_user_request_duration_seconds</code>, rather than health-check traffic, so
  the reliability signal aligns with a caller’s <code>/pay</code> experience.

There are exactly two primary SLOs: 99.5% availability and 95% of <code>/pay</code> requests
under 500 ms. The availability objective leaves a 0.5% error budget, which lets the
team discuss whether an incident is consuming reliability capacity rather than just
whether a graph looks bad.

### Operating and proving it

Terraform defines a small zonal GKE development foundation, and GitHub Actions is
designed to use GitHub OIDC/Workload Identity rather than a stored service-account
key. The operational centerpiece is a controlled Payments degradation: capture a
baseline, introduce one reversible fault, observe the user-facing SLI and alert,
diagnose with metrics/logs/Kubernetes state, clean up or roll back, then record the
recovery and postmortem.

The important limitation is honesty: configuration is present, but test and incident
claims require dated evidence. The evidence tree and runbooks define exactly what
must be captured before I call the behavior validated.

## 5 minutes

### 1. Start with the architecture

The project is deliberately one request path deep enough to teach SRE tradeoffs:

~~~text
GitHub Actions (OIDC)
        │
        ├── builds immutable images → Artifact Registry
        └── deploys reviewed Helm values → GKE

client → Envoy → API (/pay) → Payments (/process)
                  │
                  └── Redis (tenant rate-limit state)

metrics → Prometheus → Grafana
logs    → Loki       → Grafana
~~~

The point is not to claim production-scale multi-region availability. It is to make
each dependency and reliability control inspectable in one repository.

### 2. Explain the customer signal first

A common monitoring mistake is alerting on a component signal that does not match what
a user sees. Here the primary availability and latency SLOs are defined around the
instrumented <code>/pay</code> request path. The metric contract is
<code>sre_api_user_requests_total</code> and
<code>sre_api_user_request_duration_seconds</code>; the <code>status_class</code> label distinguishes
server failures. Health, readiness, and <code>/metrics</code> traffic should not improve the
SLO artificially.

The availability target is 99.5%, so the allowed bad-event fraction is 0.5%. If there
are 10,000 qualifying requests, that means 50 server-error responses fit in budget.
Burn rate describes how quickly the current error rate spends that allowance.

### 3. Walk through the reliability layers

At the application edge, rate limiting gives a predictable response when one tenant
exceeds its allowance. At the proxy, retry and timeout settings are useful only when
they are bounded: retrying every failure indefinitely can amplify a bad dependency.
Circuit-breaker limits and outlier detection prevent one unhealthy upstream from
using unlimited connections or requests.

At the Kubernetes layer, readiness determines whether a replica can receive traffic;
HPA is intended to react to resource demand; and PDBs protect voluntary disruptions.
A PDB is specifically tested through the eviction API—not a direct pod deletion,
which bypasses the guarantee being tested.

### 4. Describe the operating loop

The planned exercise is a Payments failure or latency injection. The expected
investigation order is:

1. establish baseline traffic, availability, p95 latency, pod/endpoints, and alert state;
2. introduce one reversible fault with an approved non-production target;
3. check the canonical user-facing SLI and error-budget/burn signal;
4. correlate API and Payments logs, Envoy counters, Kubernetes events, and dashboard
   panels;
5. remove the fault or roll back the proven triggering release;
6. verify recovery with the same SLI and alert path; and
7. attach real artifacts to the evidence tree and write the postmortem.

This turns “I configured monitoring” into a falsifiable procedure. If the alert does
not fire, that is a valid outcome: document the blind spot and fix it rather than
claiming detection worked.

### 5. Close with platform and cost choices

The GCP development design uses a zonal GKE cluster, a bounded node pool, one Artifact
Registry repository, and keyless GitHub authentication. Terraform owns the foundation
so it can be reviewed and destroyed after a short validation session. The teardown
document requires confirming project/state/workspace before destroy and notes that
shared GCP APIs and optional remote state are intentional leftovers.

### What I can claim today versus after validation

| Claim | Appropriate wording now | Evidence needed to strengthen it |
| --- | --- | --- |
| Resilience controls | “Envoy/Kubernetes/rate-limit controls are configured in the repository.” | Rendered/applied manifests and a fault test showing their observed behavior. |
| SLOs and alerts | “The canonical /pay SLI and two SLO definitions are documented/configured.” | Prometheus query, dashboard, and firing/resolved alert evidence. |
| GKE delivery | “Terraform and CI workflows define a keyless GKE delivery path.” | Reviewed apply/deployment and cluster health evidence. |
| Incident response | “A controlled-incident runbook and postmortem template are ready.” | Timestamped baseline, fault, mitigation, recovery, and completed postmortem. |

A strong interview answer is specific about the design and equally specific about what
has been measured. That distinction makes the project more credible, not less.
