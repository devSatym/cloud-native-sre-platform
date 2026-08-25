# Retired standalone Envoy manifests

Envoy is now rendered by the main Helm chart at
[`../helm/templates/`](../helm/templates/). The old standalone manifests used a
fixed namespace, hard-coded service names, and a mutable image tag, so they were
removed rather than left applyable beside the release-safe chart.

Use `helm template` or `helm upgrade --install` with `deploy/helm/`; do not apply
resources from this directory directly.
