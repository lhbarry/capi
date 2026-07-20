# Reliability controls

| Path | Purpose |
|------|---------|
| [../aws_eks/services/lgtm/](../aws_eks/services/lgtm/) | **Primary** metrics/logs/traces + **alerts** (replaces CloudWatch alarms) |
| [../aws_eks/services/velero/](../aws_eks/services/velero/) | Backup/restore |
| [../docs/reliability.md](../docs/reliability.md) | RTO/RPO, failure modes |
| [quotas.md](quotas.md) | Service quota watchlist |
| [alarms.yaml](alarms.yaml) | Stub — CloudWatch alarms **removed** in favor of LGTM |

## Alerting (LGTM)

```bash
# After monitoring CRDs / Grafana k8s-monitoring installed on Services:
kubectl apply -k aws_eks/services/lgtm/alerts/
```

Rules: node NotReady, kubelet down, crashloop, CPU/memory/disk — see `lgtm/alerts/`.
