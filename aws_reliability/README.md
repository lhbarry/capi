# Reliability controls (AWS + docs)

| Path | Purpose |
|------|---------|
| [alarms.yaml](alarms.yaml) | CloudWatch alarms (EKS Container Insights + hooks) |
| [quotas.md](quotas.md) | Service quota watchlist |
| [../docs/reliability.md](../docs/reliability.md) | RTO/RPO, failure modes |
| [../aws_eks/services/velero/](../aws_eks/services/velero/) | Backup/restore |
| [../aws_eks/reliability/](../aws_eks/reliability/) | PDBs, topology spread |

```bash
# After SNS topic exists and Container Insights enabled:
aws cloudformation deploy \
  --stack-name scke-reliability-alarms \
  --template-file aws_reliability/alarms.yaml \
  --parameter-overrides AlarmTopicArn=arn:aws:sns:...
```
