# Contributing

Thanks for improving the Cloud-Native Reliability Engineering Platform. Keep changes
small, reproducible, and evidence-based.

## Before opening a pull request

1. Branch from the repository's active default branch.
2. Run `make lint` and `make test`.
3. When changing Kubernetes or Terraform configuration, run the corresponding render or
   validation command and include its result in the pull request.
4. Update runbooks, SLO documentation, or evidence instructions when behavior changes.
5. Never commit credentials, kubeconfigs, Terraform state, or fabricated evidence.

## Commit and review guidance

Use clear, conventional-style commit messages such as `feat(helm): add Envoy ingress`
or `fix(alerts): use the user-facing error signal`. A pull request should explain what
changed, why it matters for reliability, how it was validated, and any remaining
cloud-only validation requirement.

## Testing expectations

- Unit tests cover service and middleware behavior.
- Compose integration tests exercise API → Payments rather than only direct service
  endpoints.
- Helm changes render cleanly.
- Terraform changes pass formatting and validation.
- GKE experiments record real output under `docs/evidence/`; a planned or unavailable
  experiment is labelled as such.

See [the development guide](docs/DEVELOPMENT.md), [runbooks](docs/runbooks/README.md),
and [the evidence ledger](docs/evidence/README.md) for operational details.
