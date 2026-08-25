# Implementation Plan — Cloud-Native Reliability Engineering Platform

**Prepared:** 2026-08-25
**Basis:** [current-state audit](audit/current-state-audit.md) and `plan.md`
**Rule:** implementation and evidence are kept separate. A configuration is never described as validated until the corresponding command output, metric, or test result exists.

**Status:** Audit-baseline implementation plan. The statements in the next two
sections describe the repository *before* the implementation work recorded in the
root README. They are retained to show the decision path; consult the README and
evidence ledger for current status.

## Audit-baseline current state

At audit time, the repository was a useful local Kubernetes resilience lab, not yet
a GKE platform. It already contained:

- FastAPI API and Payments services, Redis rate limiting, unit tests, and Compose integration tests.
- Envoy retry, timeout, backoff, circuit-breaker, and outlier-detection configuration.
- A Helm parent chart with API/Payments subcharts, Redis, HPAs, PDBs, probes, resource controls, and NetworkPolicies.
- Prometheus rules/ServiceMonitors, Grafana dashboards, Loki values, fault scripts, runbooks, and historical local experiment artifacts.

It did not contain Terraform, GCP Workload Identity Federation, Artifact Registry
delivery, a GKE deployment path, SLO/error-budget rules, valid HPA/PDB experiments,
or current GKE evidence. The historical latency incident also established a specific
alerting defect: user-facing 504s were not seen by an API-only error alert.

## Problems found

- Active deployment configuration is tied to `resilience-lab`, a previous owner, GHCR, fixed local image tags, and `latest`.
- Envoy and observability resources are outside the application Helm release, so deployment is not one reproducible workflow.
- API-to-Payments traffic bypasses Envoy's Payments retry, timeout, circuit-breaker, and outlier policy; existing NetworkPolicies conflict with that direct path.
- HPA historical output shows unavailable metrics and no observed scale-up. PDB evidence uses direct deletion, which bypasses voluntary-disruption protection.
- The existing k6 scripts do not consistently target the rate-limited user route.
- SLOs, error budgets, burn alerts, a user-facing error signal, and evidence capture are absent.
- PostgreSQL is started/configured but not used by application code; existing documentation makes contradictory claims about it.
- Cloud execution requires a billing-enabled project, bootstrap permissions, a state backend decision, and GitHub repository/environment variables. Those are not available in this repository.

## Preserve, remove, and add

### Preserve

- The `services/` layout and small FastAPI services.
- Redis-backed tenant rate limiting, while making its configuration and failure behavior explicit.
- Envoy resilience settings, tightened and exercised through the actual API flow.
- The existing `deploy/helm` chart path and local subcharts; moving it only to match a sample tree would add churn.
- Kubernetes probes, resource requests, HPA/PDB concepts, NetworkPolicies, fault injection, existing dashboards, Loki/Prometheus values, and useful historical runbooks.
- Trivy, unit tests, Compose integration testing, and Docker non-root controls.

### Remove from active deployment

- Unused PostgreSQL service/value/environment scaffolding. Payments remains explicitly in-memory for this intentionally small portfolio workload.
- Active `latest` deployment tags, GHCR publishing, static Grafana passwords, and fixed old project/repository identities.
- Helm templates that hard-code namespace or release resource names.
- The public `/payments` route as a normal user entry point. API-to-Payments calls will instead use Envoy's internal `/payments` route so its resilience policy is exercised.

### Add

- Portable examples: `.env.example`, `deploy/helm/values-dev.example.yaml`, and Terraform examples.
- Terraform modules for network, GKE, Artifact Registry, and GitHub WIF.
- GCP OIDC workflows for CI, image publishing, deployment, Terraform plan, and guarded Terraform apply.
- A self-contained Helm release: Envoy config/deployment/service, standard Kubernetes Ingress, configurable images, security context, PDB/HPA/NetworkPolicy switches, and release-safe names.
- Canonical API user-request metrics, exactly two primary SLOs, error-budget calculations, focused alerts, and a primary golden-signals dashboard.
- Focused k6 tests, cluster/evidence capture scripts, a validation script, PDB and incident runbooks, a postmortem template, cost guidance, and interview documentation.

## Terraform design

`terraform/environments/dev` will compose four small modules:

1. **network** — a custom VPC, one regional subnet, GKE Pod/Service secondary ranges, and only required health-check/firewall rules.
2. **gke** — a cost-conscious **zonal Standard GKE** cluster. Workload Identity and network-policy enforcement are enabled. A managed node pool starts at two nodes to make PDB experiments possible, with a modest 2–3 node autoscaling range.
3. **artifact-registry** — one Docker repository containing the `api` and `payments` image packages. Image references use `REGION-docker.pkg.dev/PROJECT/REPOSITORY/<service>:<git-sha>`.
4. **github-wif** — a GitHub OIDC workload identity pool/provider with an `assertion.repository` restriction, a low-privilege deployer service account, and a separately documented Terraform executor bootstrap path.

The development environment receives `project_id`, `region`, `zone`, `github_repository`, repository name, and cluster name as variables. It does not embed a project ID, GitHub owner, domain, state bucket, credentials, or secrets. Remote state is opt-in through `backend.tf.example`; a real backend is selected before `terraform init` in a shared environment.

## CI and delivery design

| Workflow | Trigger | Responsibility |
|---|---|---|
| `ci.yml` | Pull requests and pushes | Ruff, unit tests, Compose API-flow integration test, Helm lint/template, manifest schema validation, and failing Trivy filesystem scan. |
| `build-images.yml` | `main` after code changes | GitHub OIDC → WIF, build API/Payments, Trivy image gate, Artifact Registry push with the immutable commit SHA. |
| `deploy.yml` | Successful image-build workflow / manual dispatch | Authenticate to GKE through WIF and run `helm upgrade --install` using SHA image overrides. |
| `terraform-plan.yml` | Pull requests affecting Terraform / manual dispatch | Format, initialize, validate, and produce a no-refresh plan using WIF and configured repository variables. |
| `terraform-apply.yml` | Explicit manual dispatch from `main` | Requires a confirmation input, then applies with the Terraform executor identity. |

No workflow uses a JSON service-account key or deploys an application image by `latest`.

## GKE and Helm design

The retained chart at `deploy/helm` will be the application release. The standard Kubernetes Ingress routes external `/api` traffic to Envoy. Envoy routes `/api` to API and its internal `/payments` route to Payments. The API's in-cluster `PAYMENTS_URL` points at Envoy's internal service route, so retry, per-try timeout, backoff, circuit breakers, outlier detection, and bulkhead limits protect the API-to-Payments dependency.

The chart will support:

- API/Payments SHA images, replica counts, requests/limits, liveness/readiness/startup probes, HPA, and PDB.
- Redis, Envoy config/deployment/service, standard Ingress, ConfigMaps, optional image pull secrets, and NetworkPolicies.
- API HPA `minReplicas: 1`, `maxReplicas: 3`, and a 65% CPU target with realistic CPU requests.
- Two replicas for the PDB validation override, with `minAvailable: 1`.
- Default-deny ingress and egress policies plus explicit DNS, ingress-controller → Envoy, Envoy → API/Payments, API → Envoy/Redis, and monitoring scrape paths.
- Non-root, read-only filesystem, dropped capabilities, no privilege escalation, seccomp defaults, and disabled service-account-token mounting where a workload does not require Kubernetes API access.

The legacy Traefik manifest is removed from active deployment; a short retirement
note remains for migration context. The active GKE path uses a configurable standard
Ingress class. DNS/TLS remains an environment decision and is not claimed as
configured without a real domain and certificate.

## SLO design

Exactly two primary SLOs will be implemented. The API will emit a small, bounded-label `sre_api_user_*` metric series only for the user-facing `/pay` operation. This avoids inventing unreliable path labels and excludes `/healthz`, `/readyz`, and `/metrics` by construction.

| SLO | Target | SLI | Recording / alerting design |
|---|---:|---|---|
| API availability | 99.5% | successful `/pay` responses ÷ all `/pay` responses | 30-day availability recording rule, 0.5% error budget, remaining/consumed budget, user-facing `HighErrorRate`, fast and slow burn alerts. |
| API latency | 95% under 500 ms | `/pay` histogram observations at or under 500 ms ÷ all `/pay` observations | 30-day good-latency ratio plus a short-window p95 `HighLatency` alert. |

Fast burn will use a short window with high budget consumption; slow burn will use a longer window with moderate consumption. Query names and labels will be introduced by the application and tested in the rendered `PrometheusRule`, rather than assuming an exporter-specific metric label.

## Incident experiment

The single showcase experiment is a Payments failure/degradation:

```text
baseline user traffic
  → inject reversible Payments failure or latency
  → API user SLI degrades
  → user-facing error/latency or SLO burn alert fires
  → inspect Grafana and Prometheus
  → confirm Payments fault in Loki and Envoy counters
  → remove fault / roll back configuration
  → verify health, traffic, SLI, and alert recovery
  → save measured evidence and complete the postmortem
```

The accompanying postmortem initially uses `TO BE CAPTURED DURING VALIDATION` placeholders. It will only contain numerical impact, duration, or recovery claims after the experiment is run.

## Expected final repository shape

```text
cloud-native-sre-platform/
├── .github/workflows/
├── services/
│   ├── api/
│   └── payments/
├── deploy/
│   ├── helm/
│   ├── prometheus/
│   ├── loki/
│   └── envoy/                 # legacy/local reference after chart integration
├── terraform/
│   ├── modules/
│   └── environments/dev/
├── sre/
│   ├── alerts/
│   ├── recording-rules/
│   └── slos/
├── tests/load/
├── scripts/
│   └── evidence/
├── docs/
│   ├── audit/
│   ├── evidence/
│   ├── interview/
│   ├── postmortems/
│   ├── runbooks/
│   └── sre/
├── README.md
├── LICENSE
└── Makefile
```

`services/` and `deploy/helm/` deliberately remain in place because their existing implementation is useful and the target plan explicitly prioritizes minimal disruption over cosmetic reorganization.

## Implementation phases

1. **Phase 0 — audit:** complete this audit and plan before architecture changes.
2. **Phase 1 — portability:** remove unused runtime scaffolding, normalize names/configuration, add safe examples, and repair developer commands/tests.
3. **Phase 2 — Terraform:** add the GCP network/GKE/Artifact Registry foundation.
4. **Phase 3 — WIF:** add keyless GitHub OIDC federation and least-privilege identities.
5. **Phase 4 — CI/CD:** replace GHCR/latest publishing with SHA-tagged Artifact Registry workflows.
6. **Phase 5 — Helm/GKE:** make the active release self-contained, parameterized, and GKE-compatible.
7. **Phase 6–9 — reliability validation:** correct traffic policies; add rate-limit, bulkhead, HPA, and PDB test procedures.
8. **Phase 10–13 — observability/SRE:** add golden signals, two SLOs, error budgets, burn alerts, and the user-facing error alert.
9. **Phase 14–16 — incident/evidence:** add a controlled incident procedure, runbooks, postmortem placeholders, capture scripts, and evidence directories.
10. **Phase 17–18 — documentation/validation:** rewrite README and interview material, run every available static/local validation, then run the live GKE checklist when cloud inputs are available.

## Potential blockers

- A billing-enabled GCP project, selected region/zone, enabled APIs, and a safe remote-state backend are needed for `terraform apply`.
- Bootstrap authorization is needed to create the WIF pool and initial service-account bindings; WIF cannot authenticate the very first creation of itself.
- GitHub Actions needs repository/environment variables for project ID/number, region, cluster, Artifact Registry repository, WIF provider, and service-account emails.
- A real ingress hostname and TLS decision are needed for externally reachable HTTPS, but not for internal functional validation.
- The current kubeconfig points at an unreachable cluster; it must not be treated as evidence for this project.

These block live validation only. Static configuration, local tests, scripts, and documentation will be implemented and validated before requesting cloud execution.

## Risk and rollback strategy

- All application deployments use immutable SHA tags, so a rollback is `helm rollback` or a `helm upgrade` using the prior known SHA.
- Fault commands have explicit cleanup and are restricted to a selected namespace/release; elevated network capability is opt-in and removed immediately after the experiment.
- Terraform is reviewed through plan output before an explicit apply. Development infrastructure is removed with `terraform destroy` after evidence collection.
- NetworkPolicy changes are applied with a documented verification sequence and a release rollback path to avoid lockout.
- No historical result is overwritten or relabeled as GKE evidence; new evidence is stored separately with command, UTC timestamp, and environment metadata.
