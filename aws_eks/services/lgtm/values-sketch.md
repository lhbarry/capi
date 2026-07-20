# Install sketch (Services)

Preferred: **Grafana k8s-monitoring** Helm chart or **Loki + Mimir + Tempo + Grafana** charts in `observability` namespace.

## Minimum components

| Component | Role |
|-----------|------|
| Grafana | UI + alert routing |
| Mimir (or Prometheus + remote write) | Metrics |
| Loki | Logs |
| Tempo | Traces |
| Alloy / OTel / Fluent Bit | Collectors |
| kube-state-metrics + node-exporter | Cluster/node metrics for LGTM alerts |

## Alert routing

Grafana Alertmanager → SNS / MS Teams / email (on-prem Teams already in architecture).

**Do not** create CloudWatch Alarms for the same conditions (duplicate paging).
