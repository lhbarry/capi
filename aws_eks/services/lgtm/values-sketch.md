# Install sketch (Services) — diagram services only

| Diagram component | Install approach |
|-------------------|------------------|
| **Grafana LGTM** (Loki · Tempo · Mimir) | Grafana Helm charts / k8s-monitoring **with OTel**, or separate L/G/T/M charts |
| **OpenTelemetry** Collector · OTLP | OpenTelemetry Operator + Collector CR, or contrib Helm chart |

Collectors are **OpenTelemetry only** (gateway on Services, agents on Workload).

## Alerting

Grafana Alertmanager / Mimir ruler using rules under `alerts/`.  
Route to MS Teams (on-prem diagram) / email — not CloudWatch Alarms.
