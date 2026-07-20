# LGTM observability stack (Services cluster)

**Canonical observability backend** for the platform: **Grafana · Loki · Tempo · Mimir** (plus OpenTelemetry collectors).

| Signal | Path |
|--------|------|
| Metrics | kube-state-metrics / node / app OTel → **Mimir** → Grafana |
| Logs | apps + system → OTel/Fluent Bit → **Loki** → Grafana |
| Traces | apps → OTel → **Tempo** → Grafana |
| Alerts | **Mimir / Grafana** alert rules → Alertmanager → SNS/Teams/email |

## CloudWatch policy (LGTM-first)

| AWS feature | Keep? | Why |
|-------------|-------|-----|
| EKS CAPA `logging:` (api/audit/…) | **Yes (bridge only)** | AWS only delivers EKS **control-plane** logs to **CloudWatch Logs** |
| CloudWatch Alarms / Container Insights for app REL | **No** | Use **LGTM alerts** instead |
| CloudTrail → CloudWatch Logs | **No** | CloudTrail → **S3** (detection); optional later ship S3→Loki |
| SSM AMI parameter paths | N/A | Not observability |

**Bridge:** Fluent Bit / OTel Collector on Services (and agents on Workload) with `awscloudwatch` / subscription filter → **Loki**. Operators use **Grafana**, not the CloudWatch console, for day-2.

## Layout

| Path | Purpose |
|------|---------|
| [architecture.md](architecture.md) | Data paths, multi-cluster scrape |
| [alerts/](alerts/) | Prometheus/Grafana-style alert rules (Mimir/Grafana) |
| [collectors/](collectors/) | OTel / Fluent Bit sketches |
| [values-sketch.md](values-sketch.md) | Helm install notes (Grafana k8s-monitoring or kube-prometheus + LGTM) |

## Install target

- **Services cluster** hosts LGTM backends (HA later).  
- **Workload** runs lightweight collectors shipping to Services (or regional gateway).  
- Auth: Grafana behind OAuth2 Proxy + Keycloak.
