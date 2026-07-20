# LGTM architecture (diagram-aligned)

**Telemetry agent (only):** [OpenTelemetry](https://opentelemetry.io/) — Collector · OTLP (diagram: Services plane DATA & OBSERVABILITY).  
**Backend (only):** Grafana LGTM — Loki · Tempo · Mimir (diagram).

**Fluent Bit is not in the architecture** and must not be introduced.

```text
Workload cluster                         Services cluster
┌──────────────────────────┐            ┌─────────────────────────────┐
│ OpenTelemetry Collector  │──OTLP─────►│ OpenTelemetry Collector     │
│ (agents / daemon)        │            │ (gateway)                   │
│                          │            │        │                    │
│ apps / nodes / Knative   │            │        ├─► Mimir  (metrics) │
│ Argo Agent, …            │            │        ├─► Loki   (logs)    │
└──────────────────────────┘            │        ├─► Tempo  (traces)  │
                                        │        └─► Grafana (UI+alert)│
Management (optional OTel) ──OTLP──────►│                             │
                                        └─────────────────────────────┘
```

## Signal map (catalog §7)

| Signal | Collector | Backend |
|--------|-----------|---------|
| Metrics | OpenTelemetry | **Mimir** → Grafana |
| Logs | OpenTelemetry | **Loki** → Grafana |
| Traces | OpenTelemetry | **Tempo** → Grafana |
| Alerts | — | Grafana / Mimir ruler → Alertmanager |

## EKS control-plane logs (AWS constraint)

CAPA `logging:` enables EKS control-plane log delivery. **AWS only accepts CloudWatch Logs as that delivery target** — that is an AWS API constraint, **not** a diagram “AWS Services” product choice and **not** a new architecture box.

**Architecture path:** OpenTelemetry Collector (with AWS CloudWatch Logs **receiver** in the collector config) reads those groups and exports to **Loki**. Day-2 operators use **Grafana**, not the CloudWatch console.

No Fluent Bit. No Firehose/Lambda as architecture components unless you explicitly add them later.

## Out of scope for this stack

- CloudWatch Alarms / Container Insights as primary REL monitoring  
- Extra log shippers not named in ARCHITECTURE.md §7  
