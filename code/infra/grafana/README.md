# HNAG Grafana dashboards

Pre-built dashboards for the metrics emitted by `/metrics` (Prometheus
text exposition; see `code/backend/src/modules/health/metrics.controller.ts`).

## Import (30 seconds)

1. In Grafana, **Dashboards → New → Import**.
2. Drop one of the `*.json` files from this directory.
3. Pick your Prometheus data source.
4. Save.

## Dashboards

- **hnag-health.json** — process health, DB/Redis liveness, queue depth,
  memory. Includes a "Queue backed up" alert (waiting > 50 for 5 min).
  Refresh: 30s. Default window: last 1h.

- **hnag-ai-spend.json** — today's LLM spend USD, distinct users, cost
  per user, projected monthly burn. Color-coded thresholds: green < $5
  daily / yellow / red > $20. Refresh: 1m. Default window: last 7d.

## Prometheus scrape config

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: hnag-backend
    static_configs:
      - targets: ['hnag-backend:4000']
    metrics_path: /metrics
    scrape_interval: 15s
```

## Adding more dashboards

When you ship a new metric in `metrics.controller.ts`:

1. Add it under a clear `# HELP` + `# TYPE` line.
2. Build the dashboard in Grafana UI.
3. **Dashboard settings → JSON Model**, copy, save as
   `hnag-<topic>.json` in this directory.
4. Update this README's panel list.

## What's not here yet

- Latency histograms per HTTP route — needs `prom-client` Histogram
  instrumentation in the request middleware. Defer until traffic
  justifies the storage cost.
- Trace exemplars — when OpenTelemetry (see
  `code/backend/src/common/config/tracing.ts`) is actually deployed,
  link the Prometheus exemplar field to Tempo / Jaeger.
