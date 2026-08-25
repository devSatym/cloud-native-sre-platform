# SRE configuration source

The deployable SLI, SLO, error-budget, and alert rules live in
[`deploy/helm/templates/prometheus-rules.yaml`](../deploy/helm/templates/prometheus-rules.yaml)
so they are released with the workload rather than copied manually. This directory
documents the intended SRE layout without creating a duplicate source of truth.

See [SLOs](slos/README.md), [recording rules](recording-rules/README.md), and
[alerts](alerts/README.md).
