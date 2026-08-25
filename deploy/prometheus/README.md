# Prometheus and Grafana configuration

Install the pinned observability stack with:

```bash
make observability-up
```

The application Helm release owns its `ServiceMonitor` and `PrometheusRule` resources.
After the stack's CRDs exist, deploy the application with `MONITORING_ENABLED=true` so
the API, Payments, Envoy, SLI/SLO, and alert configuration are rendered together.

`values.yaml` intentionally does not contain an administrator password or notification
secret. Retrieve the chart-generated Grafana password from the cluster only when needed;
do not copy it into evidence files.
