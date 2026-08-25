# Validation Evidence

**Status:** Evidence structure created; no validation output has been captured in this directory yet.

This tree is the repository's evidence ledger. It holds outputs from real executions
only; configuration files and documentation show intent, not proof that a deployment,
test, alert, or recovery worked.

## Evidence standard

Each captured item must make it possible to answer these questions without relying on
memory:

- What was tested or observed?
- Which environment, cluster, namespace, and revision were involved?
- When was it captured (UTC)?
- Which command, query, or test produced it?
- What result was observed?

Use a descriptive, UTC-prefixed name such as
`2026-08-25T103000Z-hpa-before.txt`. Keep an adjacent Markdown note or capture
metadata when the command, query, context, or redactions are not obvious from the
artifact itself. Never commit credentials, bearer tokens, kubeconfigs, Terraform
state containing secrets, private endpoints, or unredacted customer/payment data.

## Status expectations

| Situation | Correct status language | What belongs here |
| --- | --- | --- |
| A manifest, dashboard, alert rule, or script exists but has not been exercised | **Configured** / **Validation pending** | No synthetic result. Link to the configuration and record the intended validation command. |
| A command or test ran and its output was retained | **Validated for the recorded environment and time** | Raw output, k6 summary, query export, or screenshot plus its command/query and context. |
| A test was attempted but did not meet its success criteria | **Attempted; not validated** | The real output, failure details, cleanup result, and follow-up work. |
| Evidence is no longer representative after a material configuration change | **Stale** | Retain it for history, label it stale, and recapture after validation. |

An empty evidence category means **not yet captured**, not that the capability passed
or failed. Do not add example terminal output, invented graphs, benchmarks, alert
history, or placeholder screenshots.

## Categories

| Directory | Expected evidence once validation occurs |
| --- | --- |
| `ci/` | GitHub Actions run links or redacted screenshots/log exports for build, test, scan, and deployment checks. |
| `terraform/` | Redacted `plan`/`apply` or destroy verification summaries, with workspace and project context. |
| `gke/` | Cluster and node readiness, namespace/release state, and non-secret deployment checks. |
| `observability/` | Prometheus target/rule checks, Grafana panels, and Loki investigation queries. |
| `hpa/` | Timestamped HPA state before, during, and after a real load experiment. |
| `pdb/` | PDB status, pod/node state, eviction response, events, and recovery observations. |
| `resilience/` | Fault injection command, relevant Envoy/application signals, cleanup, and recovery evidence. |
| `slo/` | SLI query results, SLO/error-budget view, and burn-alert state for a known time window. |
| `incident/` | Controlled-incident timeline, alert, metrics/logs, mitigation, recovery, and postmortem references. |

The `.gitkeep` files only preserve the empty category layout; they are not evidence.

## Capture discipline

1. Record the target first: cloud project (if applicable), cluster, namespace,
   Helm release, image or Git revision, and UTC time.
2. Capture a baseline before the experiment, then capture the fault/scale/eviction
   condition, cleanup, and recovery.
3. Prefer text for commands and Prometheus queries; pair Grafana screenshots with
   the exact panel/query and time range.
4. Redact before committing, while preserving enough context to interpret the
   result.
5. Link the captured artifact from the relevant runbook or postmortem and mark
   that document **Validated** only when its stated success criteria are met.
