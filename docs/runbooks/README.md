# Operational Runbooks

Current GKE procedures are intentionally separated from historical local-lab notes.
An existing document is not validation evidence: follow the current procedure,
capture the real result, and update the relevant evidence ledger only after it has
been exercised.

## Current procedures

| Runbook | Status | Purpose |
| --- | --- | --- |
| [High user-facing payment error rate](high-payment-error-rate.md) | Draft; validation pending | Diagnose and mitigate the canonical Payments incident. |
| [PDB eviction test](pdb-eviction-test.md) | Draft; validation pending | Validate a PDB through the eviction API, not direct deletion. |
| [Prometheus cannot scrape API metrics](TROUBLESHOOTING_PROMETHEUS_SCRAPE.md) | Current procedure; validation pending | Diagnose API endpoint, ServiceMonitor, Redis readiness, and scrape discovery. |
| [Application observability targets unhealthy](TROUBLESHOOTING_OBSERVABILITY_TARGETS.md) | Current procedure; validation pending | Diagnose stack prerequisites, selector labels, policies, and Prometheus targets. |
| [Runbook template](TEMPLATE.md) | Template | Start a new evidence-aware operating procedure. |

## Historical local-lab records

The remaining older runbooks document a previous Minikube/Traefik-based lab. They
may contain fixed namespaces, old image references, direct pod-deletion examples,
or historical observations. They are retained as historical context only and must
not be used as current GKE instructions or presented as current validation:

- `chaos-pod-kill.md`
- `chaos-latency-injection.md`
- `rollback-vs-recover.md`
- `TROUBLESHOOTING_HELM_FIELD_CONFLICTS.md`
- `TROUBLESHOOTING_MINIKUBE_IMAGES.md`

See the [evidence ledger](../evidence/README.md) for the required capture standard
and the [implementation plan](../implementation-plan.md) for the current target
architecture.
