# SRE Concepts: Interview Answers

**Evidence note:** “Where it exists” identifies repository configuration or
documentation. It does not mean the feature has been exercised successfully unless a
dated artifact is linked from the evidence ledger.

## Service-level indicator (SLI)

**Definition:** An SLI is a measured number that describes a service outcome, usually a
ratio such as successful requests divided by total qualifying requests.

**Why it matters:** It replaces vague statements like “the service looks healthy” with
a signal that can be tracked and improved.

**Where it exists in this project:** The intended user-facing <code>/pay</code> metric
contract is <code>sre_api_user_requests_total</code> and
<code>sre_api_user_request_duration_seconds</code>. The definition is in
[<code>docs/sre/slo-and-error-budget.md</code>](../sre/slo-and-error-budget.md).
Metric scraping and results still need validation evidence.

**Likely interview question:** Why not use a pod-ready count as the availability SLI?

**Answer:** Pod readiness is useful operational context, but it does not prove callers
can complete <code>/pay</code>. The primary SLI should follow the user-facing request
path; pod state is a supporting diagnostic signal.

## Service-level objective (SLO)

**Definition:** An SLO is the target for an SLI over a defined time window.

**Why it matters:** It turns a reliability goal into a measurable decision boundary for
engineering and operations.

**Where it exists in this project:** Two primary objectives are documented: 99.5%
availability and 95% of user-facing <code>/pay</code> requests within 500 ms. The
proposed window is 30 rolling days; dashboard/rule validation is pending.

**Likely interview question:** Why only two SLOs?

**Answer:** A small project needs objectives that people can understand and act on.
Availability and latency cover the main user experience without creating a large,
unvalidated SLO catalog.

## Service-level agreement (SLA)

**Definition:** An SLA is an external contractual commitment, often with consequences
such as service credits, based on one or more SLOs.

**Why it matters:** It distinguishes an internal engineering target from a promise made
to customers.

**Where it exists in this project:** No customer SLA is declared. The documented SLOs
are internal portfolio-project objectives, not legal or commercial commitments.

**Likely interview question:** Is a 99.5% SLO automatically an SLA?

**Answer:** No. An SLO is an internal target. It becomes an SLA only when an agreement
defines the commitment, measurement details, exclusions, and consequences.

## Error budget

**Definition:** The error budget is the amount of unreliability allowed by an SLO.

**Why it matters:** It makes reliability a tradeoff that can guide release and
mitigation decisions rather than a permanent demand for 100% success.

**Where it exists in this project:** The 99.5% availability target leaves a 0.5%
budget: 50 server-error responses per 10,000 qualifying requests, assuming the
documented event policy. Calculation/dashboard validation is pending.

**Likely interview question:** What do you do when the error budget is nearly gone?

**Answer:** Reduce additional reliability risk: pause risky changes, investigate the
dominant bad events, and prioritize recovery or reliability work. The response should
depend on measured budget consumption, not panic at a single error.

## Burn rate

**Definition:** Burn rate is the rate at which current bad events spend an error budget
compared with spending it evenly across the SLO window.

**Why it matters:** It distinguishes a brief, low-impact blip from a failure pattern
that will exhaust the budget quickly.

**Where it exists in this project:** The SLO documentation defines fast- and slow-burn
intent. Corresponding alert configuration and actual alert behavior must be checked in
the deployed Prometheus rules and evidence.

**Likely interview question:** What does a burn rate of 10 mean?

**Answer:** The service is spending the budget ten times faster than the rate that
would consume it evenly across the window. It does not by itself say how many users
are affected, so I check traffic and absolute error counts too.

## Golden signals

**Definition:** The golden signals are latency, traffic, errors, and saturation.

**Why it matters:** Together they give a compact first view of user impact, demand,
failure, and capacity pressure.

**Where it exists in this project:** Grafana/dashboard and Prometheus configuration
are intended to show request latency, request/error rates, and workload/proxy
saturation. The final panels and data sources require validation.

**Likely interview question:** Why are all four signals needed?

**Answer:** High latency can come from saturation without many errors; high errors can
occur at low traffic; and traffic changes affect how ratios are interpreted. Looking
at all four prevents diagnosing one graph in isolation.

## Horizontal Pod Autoscaler (HPA)

**Definition:** An HPA changes a workload’s replica count based on observed metrics,
such as CPU utilization.

**Why it matters:** It can add capacity during sustained demand and reduce it afterward,
within configured bounds.

**Where it exists in this project:** Helm templates include HPA configuration for
application workloads. It is configured behavior until a real load test shows the
replica count changing with the recorded metric.

**Likely interview question:** Does an HPA guarantee performance?

**Answer:** No. It needs accurate resource requests, available node capacity, a useful
metric, and time to react. It also cannot fix a slow downstream dependency or an
application bottleneck.

## PodDisruptionBudget (PDB)

**Definition:** A PDB limits voluntary disruptions so a minimum number or proportion of
replicas remains available during actions such as eviction or node drain.

**Why it matters:** It protects availability during maintenance, not all kinds of pod
loss.

**Where it exists in this project:** Helm templates define PDBs, and
[<code>pdb-eviction-test.md</code>](../runbooks/pdb-eviction-test.md) defines an
eviction-API test. No successful eviction evidence is recorded yet.

**Likely interview question:** Why is deleting a pod not a valid PDB test?

**Answer:** Direct deletion bypasses voluntary-disruption protection. An eviction API
request or reviewed drain is needed to see the PDB affect the operation.

## Retry

**Definition:** A retry repeats a failed request when the failure might be temporary.

**Why it matters:** It can hide a short network or replica failure, but it can also
multiply load on an already unhealthy dependency.

**Where it exists in this project:** Envoy configuration contains bounded retry policy
for upstream routes. Its observed retry behavior still needs fault-test evidence.

**Likely interview question:** When should you avoid retries?

**Answer:** Avoid or tightly control retries for non-idempotent operations, persistent
failures, and overloaded dependencies. Use a small retry count, per-try timeout, and
backoff only when the operation is safe to repeat.

## Timeout

**Definition:** A timeout bounds how long a caller waits for an operation.

**Why it matters:** Without it, slow dependencies consume connections, worker capacity,
and user patience indefinitely.

**Where it exists in this project:** The API client and Envoy route configuration have
timeouts. Their chosen values are configuration, not proof that latency faults recover
well.

**Likely interview question:** Why not just set a very long timeout?

**Answer:** A long timeout delays failure and can exhaust resources under a dependency
outage. It should be short enough to protect the caller but realistic for legitimate
work and coordinated with retry limits.

## Circuit breaker

**Definition:** A circuit breaker limits or stops work sent to an unhealthy dependency
once a threshold is reached.

**Why it matters:** It contains cascading failure and gives an unhealthy dependency
room to recover.

**Where it exists in this project:** Envoy upstream circuit-breaker thresholds are
configured as connection/request/pending-request limits. Validation must show the
actual counters and user-facing behavior under a controlled condition.

**Likely interview question:** Is a circuit breaker the same as a retry?

**Answer:** No. A retry tries again after a potentially transient failure; a circuit
breaker reduces or rejects more work when continued attempts are harmful.

## Bulkhead

**Definition:** A bulkhead isolates a limited resource pool so one dependency or tenant
cannot consume all connections, requests, or workers.

**Why it matters:** Isolation prevents one failure mode from taking down unrelated
work.

**Where it exists in this project:** Envoy request/connection/pending-request limits
serve as the configured bulkhead mechanism. Overflow-counter evidence is required
before claiming the limit was observed under load.

**Likely interview question:** How is a bulkhead different from a circuit breaker?

**Answer:** A bulkhead partitions capacity before everything is exhausted. A circuit
breaker changes behavior in response to failure. They often work together but solve
different parts of cascading failure.

## Rate limiting

**Definition:** Rate limiting bounds how many requests a client or tenant may make in a
time period.

**Why it matters:** It preserves fair access and protects shared capacity during bursts
or abusive traffic.

**Where it exists in this project:** The API has Redis-backed tenant rate-limit
middleware; the repository also contains rate-limit test configuration. The rate limit
is not considered validated until an actual user-facing endpoint shows allowed
requests followed by a real HTTP 429.

**Likely interview question:** Why use Redis for a multi-replica rate limiter?

**Answer:** In-memory counters in separate API pods disagree. A shared store lets
replicas apply one tenant’s limit consistently, provided the failure behavior and
atomicity are designed carefully.

## Fault injection

**Definition:** Fault injection deliberately introduces a reversible failure to test
detection, mitigation, and recovery.

**Why it matters:** It exposes gaps that happy-path tests and configuration review
cannot find.

**Where it exists in this project:** The repository contains a Payments fault helper
for failure, latency, slow-response, pod-kill, and cleanup scenarios, plus incident
runbooks. Every use must be approved, scoped to non-production, and captured as real
evidence.

**Likely interview question:** What makes fault injection safe?

**Answer:** A small blast radius, an explicit target, a reversible action, baseline
and stop conditions, and a cleanup/recovery check. I never inject a fault just to
produce a screenshot.

## Postmortem

**Definition:** A postmortem is a factual, blameless record of an incident, its impact,
detection, cause, recovery, and follow-up improvements.

**Why it matters:** It converts an outage or experiment into concrete system learning.

**Where it exists in this project:** The template is
[<code>docs/postmortems/payment-degradation.md</code>](../postmortems/payment-degradation.md).
It is intentionally unfilled until a controlled incident provides measured facts.

**Likely interview question:** What makes a postmortem useful?

**Answer:** It uses timestamps and evidence instead of assumptions, separates root
cause from contributing factors, and gives owned action items that are validated when
completed.
