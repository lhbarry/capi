# Management cluster reliability (RKE2 + Rancher)

## HA (locked)

- **3** server nodes, multi-AZ, etcd quorum  
- Internal NLB for API/UI  
- Instance type `m7i.xlarge` (4/16/100 gp3 SSD for etcd)  

## etcd snapshots (RKE2)

Enable scheduled snapshots on each server (or shared S3):

```yaml
# /etc/rancher/rke2/config.yaml (additive)
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 20
# etcd-s3: true
# etcd-s3-bucket: scke-mgmt-etcd
# etcd-s3-region: us-east-2
```

Document restore: [RKE2 etcd disaster recovery](https://docs.rke2.io/backup_restore).

## Rancher backup

Use **Rancher Backup** operator (Prime-supported path) on a daily schedule to S3, retention ≥ 7 daily / 4 weekly.

## Failure of Management

| Impact | Existing EKS clusters |
|--------|------------------------|
| CAPA down | **Keep running**; no create/update/delete via CAPA |
| Rancher down | UI/API unavailable; Workload Agent continues; git still SoT |

Recovery: restore etcd/Rancher from backup → rejoin CAPA → reconcile desired state from git.
