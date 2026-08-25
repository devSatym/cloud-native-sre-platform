# Recording rules

Availability, latency, request-rate, server-error, error-budget, and burn-rate rules
are rendered by the Helm `PrometheusRule`. Keeping them there ensures the rule names
match the release and ServiceMonitor configuration.
