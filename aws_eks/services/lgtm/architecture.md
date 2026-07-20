# LGTM architecture (diagram-aligned)

**Telemetry agents (only):** [OpenTelemetry](https://opentelemetry.io/) — diagram **DATA & OBSERVABILITY**.  
- **Workload:** OTel Collector **agents** (DaemonSet / node) ship OTLP  
- **Services:** OTel Collector **gateway** receives OTLP + **EKS CP logs from CloudWatch** → LGTM  

**Backend (only):** Grafana LGTM — Loki · Tempo · Mimir (diagram).

**Not in catalog:** any shipper other than OpenTelemetry.

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
                                                    ▲
AWS rail: CloudWatch (CP Logs Only) ────────────────┘
  (awscloudwatchlogs receiver on gateway)
```

## Signal map (catalog §7)

| Signal | Collector | Backend |
|--------|-----------|---------|
| Metrics | OpenTelemetry | **Mimir** → Grafana |
| App / node logs | OpenTelemetry | **Loki** → Grafana |
| Traces | OpenTelemetry | **Tempo** → Grafana |
| **EKS control-plane logs** | **CloudWatch (CP Logs Only)** → OTel gateway | **Loki** → Grafana |
| Alerts | — | Grafana / Mimir ruler → Alertmanager |

## EKS control-plane logs — investigation result

| Question | Answer |
|----------|--------|
| Can EKS CP logs go somewhere other than CloudWatch first? | **No.** AWS delivers managed EKS control-plane logs **only** to **CloudWatch Logs** (`/aws/eks/<cluster>/cluster`). CAPA `logging:` enables that path. |
| Can OpenTelemetry collect those CP logs? | **Yes.** OTel Collector **contrib** provides the **`awscloudwatchlogs` receiver**, which polls CloudWatch Logs groups and injects them into the collector pipeline (export to Loki). |
| Day-2 operator UI? | **Grafana / Loki** — not the CloudWatch console. Rail label is **CloudWatch · CP Logs Only**. |

**Architecture path:**

```text
CAPA logging: on  →  CloudWatch Logs (CP only)  →  OTel gateway (awscloudwatchlogs)  →  Loki
```

Sketch: [`collectors/otel-gateway-sketch.yaml`](collectors/otel-gateway-sketch.yaml).  
Gateway needs IRSA with `logs:FilterLogEvents` / `logs:DescribeLogGroups` (and related read APIs) on the `/aws/eks/*` groups.

## Out of scope for this stack

- CloudWatch Alarms / Container Insights as primary REL monitoring  
- Any log/metrics agent other than **OpenTelemetry**  
- Firehose / Lambda bridges unless explicitly added to the catalog later  
