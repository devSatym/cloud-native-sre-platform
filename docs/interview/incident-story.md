# Incident Story: Payments Degradation

**Status:** Prepared incident narrative template. No controlled Payments degradation has
been executed and evidenced in this repository yet, so this must not be told as a
completed incident.

## The truthful version to use before validation

> I designed a controlled Payments-degradation exercise around the user-facing
> <code>/pay</code> path. The repository has a reversible fault helper, a user-facing
> SLI contract, an error-budget definition, an incident runbook, an evidence ledger,
> and a postmortem template. My next step is to run it in an approved non-production
> environment, collect the actual alert/metric/log/recovery timestamps, and update the
> story only with those facts. I would say the controls are configured, not validated,
> until that evidence exists.

This is stronger than inventing a “production incident.” It shows you understand the
difference between an operational design and an observed result.

## Completed-incident narrative template

Replace every placeholder only after the evidence and postmortem have been completed.

### Situation

**TO BE CAPTURED DURING VALIDATION:** At <code>[UTC timestamp]</code>, the
<code>[environment/cluster/namespace]</code> payment path experienced
<code>[measured user-visible symptom]</code>. The canonical <code>/pay</code> SLI
showed <code>[measured error ratio and/or latency]</code> over
<code>[query window]</code>. The affected scope was <code>[measured traffic/user
impact]</code>.

### Task

**TO BE CAPTURED DURING VALIDATION:** My responsibility was to verify the user impact,
identify whether the failure was in the API, Payments, proxy, or cluster layer, apply
the smallest safe mitigation, and confirm recovery without relying on a health check
alone.

### Action

1. I recorded the baseline and incident context: <code>[cluster]</code>,
   <code>[namespace]</code>, <code>[release/image/Git revision]</code>, and the
   Prometheus/Grafana time range.
2. I confirmed the user-facing signal using
   <code>sre_api_user_requests_total</code> and
   <code>sre_api_user_request_duration_seconds</code>, rather than probe traffic.
3. I investigated API and Payments logs, Kubernetes readiness/endpoints/events, and
   relevant Envoy counters. The evidence showed <code>[evidence-backed diagnosis]</code>.
4. I applied <code>[exact cleanup, rollback, or configuration mitigation]</code>
   because <code>[why it was the smallest reversible action]</code>.
5. I verified recovery using <code>[post-mitigation SLI query/time range]</code>,
   <code>[pod/endpoint observation]</code>, and
   <code>[alert resolved timestamp or explicit alert failure]</code>.
6. I linked the raw redacted artifacts and documented the outcome in the postmortem.

### Result

**TO BE CAPTURED DURING VALIDATION:** The first recovered pod/endpoint time was
<code>[time]</code>; the user-facing SLI recovered at <code>[time]</code>; and the
alert <code>[resolved at time / did not fire]</code>. The measured duration was
<code>[duration]</code>. The action item created from the exercise was
<code>[owner + action + validation criterion]</code>.

### Reflection

**TO BE CAPTURED DURING VALIDATION:** The key learning was
<code>[evidence-backed lesson]</code>. I would improve
<code>[alert, metric label, runbook step, resilience configuration, or test
procedure]</code> and verify it by <code>[specific follow-up test]</code>.

## Interview follow-up answers

### How did you know customers were affected?

I used the API’s user-facing <code>/pay</code> SLI rather than a readiness probe or
raw pod count. I would quote the recorded request/error/latency query and time range,
not a guessed percentage.

### What if the alert did not fire?

That is an important result. I would document the mismatch between the user-facing
SLI and the alert signal, preserve the evidence, fix the rule/instrumentation, and
repeat the controlled validation. I would not claim alerting worked because a proxy
counter changed.

### Why not just restart or delete a pod?

A restart can hide the root cause and direct pod deletion does not test a PDB. I first
use evidence to choose a reversible mitigation, such as fault cleanup or a reviewed
Helm rollback, then verify the same caller-facing signal recovered.

### What did the error budget add?

It put the error ratio in context: the 99.5% availability target allows a 0.5%
bad-event budget. Burn rate shows whether the observed error pattern needs urgent
action, not just whether one request failed.

### What is the strongest proof that the exercise worked?

A linked, timestamped chain: baseline → fault/trigger → user-facing SLI degradation
→ alert/detection → diagnosis → mitigation → recovery → alert resolution →
postmortem/action item. Screenshots alone are weaker than the query, context, and raw
output behind them.

## Evidence needed before telling the completed story

- [ ] cluster, namespace, release, Git SHA, image digest, and UTC timeline;
- [ ] baseline and degraded canonical SLI/latency queries with time ranges;
- [ ] alert state or explicit evidence that it did not fire;
- [ ] redacted API/Payments logs and relevant Envoy/Kubernetes observations;
- [ ] exact fault/mitigation/cleanup or rollback record;
- [ ] post-recovery SLI, pods/endpoints, and alert-resolution evidence; and
- [ ] completed
  [<code>payment-degradation postmortem</code>](../postmortems/payment-degradation.md)
  with owned action items.

Store the source artifacts in [<code>docs/evidence/incident/</code>](../evidence/incident/).
