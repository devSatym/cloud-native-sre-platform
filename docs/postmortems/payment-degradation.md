# Postmortem: Payment Degradation Exercise

**Status:** Template — no controlled incident execution has been recorded in this
document. It must not be presented as an incident that occurred or as validation of
the alerting/recovery flow.

## Incident metadata

| Field | Recorded value |
| --- | --- |
| Incident ID | **TO BE CAPTURED DURING VALIDATION** |
| Environment / cluster / namespace | **TO BE CAPTURED DURING VALIDATION** |
| Helm release / Git SHA / image revision | **TO BE CAPTURED DURING VALIDATION** |
| Start and end time (UTC) | **TO BE CAPTURED DURING VALIDATION** |
| Incident commander / participants | **TO BE CAPTURED DURING VALIDATION** |
| Severity | **TO BE CAPTURED DURING VALIDATION** |
| Evidence directory | [`../evidence/incident/`](../evidence/incident/) — no incident artifact linked yet |

## Summary

**TO BE CAPTURED DURING VALIDATION:** State the user-visible failure, the exercised
fault or unplanned trigger, the affected request path, duration, and final recovery
state in two or three factual sentences. Do not fill this section from the intended
scenario alone.

## Impact

| Measure | Recorded value | Evidence |
| --- | --- | --- |
| Affected user-facing route | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| Start/end of user impact (UTC) | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| Total qualifying requests | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| Error count and error ratio | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| p95 latency before/during/after | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| Availability/error-budget effect | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |
| Data-integrity effect | **TO BE CAPTURED DURING VALIDATION** | **TO BE LINKED** |

Record measured values from the canonical user-facing SLI, not health-check traffic
or an unrelated proxy counter.

## Timeline

| UTC time | Event | Supporting evidence |
| --- | --- | --- |
| **TO BE CAPTURED DURING VALIDATION** | Baseline traffic and health recorded. | **TO BE LINKED** |
| **TO BE CAPTURED DURING VALIDATION** | Fault or triggering change introduced/observed. | **TO BE LINKED** |
| **TO BE CAPTURED DURING VALIDATION** | User-facing SLI degraded. | **TO BE LINKED** |
| **TO BE CAPTURED DURING VALIDATION** | Alert fired or detection occurred. | **TO BE LINKED** |
| **TO BE CAPTURED DURING VALIDATION** | Diagnosis and mitigation began. | **TO BE LINKED** |
| **TO BE CAPTURED DURING VALIDATION** | Recovery verified; alert resolved after its evaluation window. | **TO BE LINKED** |

## Detection

**TO BE CAPTURED DURING VALIDATION:** Identify the exact alert, query, dashboard, or
human observation that detected the degradation. Include the alert labels, time it
fired, evaluation window, and whether it represented
`sre_api_user_requests_total{status_class="5xx"}` on the `/pay` path. If the alert
did not fire, state that plainly and record the observed blind spot instead of
backfilling a successful detection story.

## Root cause

**TO BE DETERMINED FROM RECORDED EVIDENCE:** State the proximate technical cause only
after correlating the fault/change record, API/Payments logs, Kubernetes state, and
user-facing metrics. A planned `FAIL_MODE`, latency injection, proxy setting, or
deployment change is a hypothesis until the executed evidence establishes it.

## Contributing factors

**TO BE CAPTURED DURING VALIDATION:** List evidence-backed conditions that increased
impact or delayed diagnosis, such as retry amplification, missing endpoint readiness,
an SLI signal mismatch, insufficient logging context, or an unclear rollback path.
Do not list generic failures merely to make the postmortem look complete.

## Mitigation

**TO BE CAPTURED DURING VALIDATION:** Record the exact reversible action taken, who
took it, when, and why it was chosen. Link the redacted command/change history and
note any rejected alternatives. For an intentional fault, record the cleanup method
and verify that the fault was actually removed.

## Recovery

**TO BE CAPTURED DURING VALIDATION:** Record the first time pods/endpoints were
healthy, the first time the user-facing SLI recovered, and the time the alert resolved.
These are different timestamps and must not be treated as interchangeable. Include
the measured recovery duration only after calculating it from captured timestamps.

## What went well

**TO BE CAPTURED DURING VALIDATION:** List only observed positives, for example a
signal that led directly to diagnosis, a safe rollback, or complete evidence capture.

## What went poorly

**TO BE CAPTURED DURING VALIDATION:** List only observed gaps, for example an alert
that did not fire, a misleading dashboard, missing labels, slow diagnosis, or a
recovery step that was unclear.

## Action items

| Action | Owner | Priority | Status | Validation evidence |
| --- | --- | --- | --- | --- |
| Verify the user-facing error alert follows the canonical `/pay` SLI. | **TBD** | P1 | Proposed | **TO BE LINKED** |
| Validate the controlled Payments degradation from baseline through recovery. | **TBD** | P1 | Proposed | **TO BE LINKED** |
| Capture the two SLO views and burn-alert behavior for the exercised window. | **TBD** | P2 | Proposed | **TO BE LINKED** |
| Update the incident runbook with evidence-backed refinements. | **TBD** | P2 | Proposed | **TO BE LINKED** |

Action items become complete only when the change and its validation evidence are
linked. A postmortem should improve the system; it is not complete because the
template has been filled in.

## Evidence completion gate

Before changing this postmortem to **Validated**, attach real, redacted evidence for:

- baseline, fault/trigger, and recovery timestamps;
- alert notification or an explicit record that it failed to fire;
- canonical SLI/error-budget and latency queries with time ranges;
- relevant Grafana, Loki, Envoy, Kubernetes, and deployment/rollback observations;
- fault cleanup and post-recovery checks; and
- the action-item owners and follow-up validation.

Store artifacts in [`../evidence/incident/`](../evidence/incident/) and reference
their exact filenames here. No sample outputs or invented incident metrics belong in
this record.
