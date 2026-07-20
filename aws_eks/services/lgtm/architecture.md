# LGTM architecture (diagram-aligned)

**Telemetry agents (only):** [OpenTelemetry](https://opentelemetry.io/) — diagram **DATA & OBSERVABILITY**.  
- **Workload:** OTel Collector **agents** (DaemonSet / node) ship OTLP  
- **Services:** OTel Collector **gateway** receives OTLP (+ optional CP-log receiver) → LGTM  

**Backend (only):** Grafana LGTM — Loki · Tempo · Mimir (diagram).

**Not in catalog:** Fluent Bit or any other shipper. Do not introduce them.

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

No extra shippers. No Firehose/Lambda as architecture components unless the owner adds them to the catalog **and** the SVG AWS rail (or Services plane) explicitly.

## Out of scope for this stack

- CloudWatch Alarms / Container Insights as primary REL monitoring  
- Any log/metrics agent other than **OpenTelemetry**  
- New AWS rail products beyond **EFS · EBS · S3**  

