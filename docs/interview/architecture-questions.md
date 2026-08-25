# Architecture Questions: Interview Preparation

**Evidence note:** Answers describe the repository’s design and configuration. Use
captured cluster/test evidence before changing wording from “configured” to
“demonstrated.”

## What is the request path?

**Answer:** The intended user path is client → Envoy → API → Payments, with Redis used
by the API’s tenant rate limiter. Prometheus receives metrics and Loki receives logs
for investigation through Grafana. The primary reliability view follows the API’s
user-facing <code>/pay</code> path, not probe traffic.

**Important nuance:** Inspect the actual routing and service client configuration in
the deployed revision. A proxy policy applies only to traffic that really traverses
that proxy; do not assume an internal API-to-Payments call inherits every Envoy
setting.

## Why use a small two-service application instead of a larger microservice system?

**Answer:** It gives enough dependency behavior to demonstrate retries, timeouts,
capacity, disruption, observability, and incident response while remaining fully
understandable. More services would create more moving parts but not necessarily more
evidence of SRE skill.

## Why is Envoy in front of the API?

**Answer:** Envoy centralizes ingress routing and can enforce bounded route behavior
such as timeouts, retries, upstream circuit-breaking limits, and outlier detection.
This is useful when configured deliberately, but it does not replace application
semantics or prove that every internal call uses Envoy.

## How do you keep retries from causing a retry storm?

**Answer:** A safe design bounds retry count, uses per-try and overall timeouts, backs
off, and only retries operations that are safe to repeat. For payment creation,
idempotency is especially important: retrying a non-idempotent operation can create
duplicates. I would verify the actual route/client path, idempotency policy, and
observed retry counters before claiming the protection works end to end.

## What is the difference between the API timeout and an Envoy timeout?

**Answer:** The API client timeout limits how long the API waits for Payments. Envoy
timeouts limit requests on routes that traverse Envoy. They should be coordinated so
the outer layer does not wait longer than necessary after an inner dependency has
already timed out. The correct values require measured latency and failure testing.

## Why use Redis for rate limiting?

**Answer:** A shared Redis-backed counter lets multiple API replicas apply a tenant
limit consistently, unlike isolated in-memory counters. The tradeoff is that Redis
availability and atomic operations become part of the request-path design. The
repository’s rate-limit test must prove a real protected endpoint returns HTTP 429
after the allowed requests.

## What makes the SLI user-facing?

**Answer:** The canonical metric contract is
<code>sre_api_user_requests_total</code> and
<code>sre_api_user_request_duration_seconds</code> for the API <code>/pay</code>
path. Health checks, readiness probes, and Prometheus scrapes must be excluded so a
healthy probe cannot hide failed payment requests.

## Why are there only two primary SLOs?

**Answer:** The project focuses on the two outcomes callers feel first: availability
(99.5%) and latency (95% under 500 ms). More objectives can be useful later, but a
small set makes alerting, dashboards, and incident decisions understandable and
testable.

## How does an error budget affect releases?

**Answer:** The 99.5% availability SLO allows 0.5% server-error responses in its
window. If failure is consuming that budget quickly, the team should reduce risk,
investigate the failure mode, and prioritize reliability work before adding risky
changes. It is an operational decision input, not a reason to ignore individual user
impact.

## Why use HPA and what are its limits?

**Answer:** HPA can scale replicas based on a configured resource signal, provided
resource requests, metrics, and node capacity are correct. It cannot instantly fix a
slow dependency, an overloaded database, or a per-pod concurrency bottleneck. A real
load experiment must show metric growth and replica movement before HPA is called
validated.

## How does a PDB improve reliability?

**Answer:** A PDB constrains voluntary disruptions such as eviction or node drain so
the configured availability threshold is preserved. It does not protect against every
unplanned crash, nor does it create replicas by itself. The correct proof is an
eviction-API or carefully reviewed drain exercise, not a direct pod deletion.

## How do you deploy to GKE without a service-account key?

**Answer:** Terraform configures a GitHub OIDC Workload Identity Federation provider
restricted to the configured repository claim. GitHub Actions obtains short-lived
credentials to act as a limited deployer identity; Terraform uses a separate,
higher-privilege executor for infrastructure. The bootstrap identity is still a
one-time prerequisite, and the actual authentication flow needs workflow evidence.

## Why use immutable image tags?

**Answer:** A Git SHA tag ties a deployed image to source and avoids the ambiguity of
a mutable <code>latest</code> tag. It makes rollback, incident correlation, and
reproducibility much clearer. The CI/deployment path must still show that the resolved
digest is the one deployed.

## How are metrics, logs, and dashboards used together?

**Answer:** Metrics quantify impact and scope, dashboards make the signals easy to
correlate, and logs provide request/error context. In an incident I start with the
canonical user-facing SLI, then correlate API/Payments logs, Envoy counters, pod and
endpoint state, and recent deployment history. A graph without the query/time range
is not sufficient evidence.

## What happens during a Payments degradation?

**Answer:** The intended exercise captures a baseline, introduces one reversible
failure or latency fault in a non-production target, checks the <code>/pay</code> SLI
and alert, diagnoses the dependency with metrics/logs/Kubernetes state, removes the
fault or rolls back the known cause, and records recovery. If a configured alert does
not fire, that is an observed gap to document and fix—not a successful test.

## Why GKE rather than a local-only cluster?

**Answer:** A local cluster is useful for rapid development, while GKE demonstrates
cloud identity, Artifact Registry, managed Kubernetes operations, and Terraform
lifecycle. The foundation intentionally stays zonal and small because the goal is a
reproducible development exercise, not a multi-region production platform.

## How do you keep cloud cost and cleanup under control?

**Answer:** The Terraform environment is bounded to a small node pool and limited
supporting services. Before destroying it, the operator checks Terraform state,
workspace, project, and a reviewed destroy plan. Terraform-managed resources can be
removed with <code>terraform destroy</code>; shared APIs and optional remote state are
intentional leftovers that need explicit ownership decisions.

## What would you improve next?

**Answer:** First complete and retain end-to-end evidence for deployment, HPA, PDB,
rate limiting, SLO alerts, and the controlled incident. Then use those results to
improve the highest-value gap—for example request idempotency, dashboard clarity,
alert tuning, or a safer dependency boundary—rather than adding features merely for
breadth.
