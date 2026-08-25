# Primary SLOs

The platform has exactly two primary SLOs: API availability at 99.5% and API latency
with 95% of `/pay` requests under 500 ms. The deployable expressions are maintained
with the Helm `PrometheusRule`; see `docs/sre/slo-and-error-budget.md` for definitions.
