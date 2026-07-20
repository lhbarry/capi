# LGTM architecture

```text
Workload cluster                    Services cluster
┌─────────────────────┐            ┌──────────────────────────────┐
│ OTel Collector      │──OTLP──────►│ Mimir  (metrics)             │
│ Fluent Bit / OTel   │──logs──────►│ Loki   (logs)                │
│ (apps, nodes)       │──traces────►│ Tempo  (traces)              │
│                     │            │ Grafana (explore + alerts)   │
│ EKS CP logs (AWS)   │            │ Alertmanager                 │
│  → CW Logs (only    │  bridge    │                              │
│    AWS sink) ───────┼───────────►│ Loki (via CW subscription /  │
│                     │            │      Fluent Bit cloudwatch)  │
└─────────────────────┘            └──────────────────────────────┘
Management RKE2
  node/agent logs ─────────────────► Loki (optional remote write)
```

## Multi-cluster

| Source | Scrape / ship |
|--------|----------------|
| Services in-cluster | Prometheus scrapes / OTel local → Mimir |
| Workload | OTel remote write / OTLP to Services gateway |
| Management | Optional Fluent Bit → Services Loki |

## What we do **not** run for platform REL

- CloudWatch Alarms on Container Insights  
- CloudWatch dashboards as primary ops UI  
- Container Insights as required dependency for reliability  

Container Insights may be enabled later for AWS support cases only — **not** architecture baseline.
