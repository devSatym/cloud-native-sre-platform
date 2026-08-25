# Loki and Promtail configuration

`scripts/deploy-observability.sh` installs the pinned `grafana/loki-stack` chart using
these values. Loki keeps a small single-cluster retention period and Promtail collects
pod logs. Grafana is supplied by kube-prometheus-stack and receives a Loki datasource
through `deploy/prometheus/values.yaml`.

Validate log ingestion with a live LogQL query and save the resulting command output
under `docs/evidence/observability/`; no static configuration is treated as log evidence.
