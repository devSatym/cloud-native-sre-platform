# Alerts

The focused alert set is `HighErrorRate`, `HighLatency`, `SLOBudgetFastBurn`,
`SLOBudgetSlowBurn`, and `ServiceDown`. It is configured in the Helm
`PrometheusRule` and must be exercised during a live fault before it is called validated.
