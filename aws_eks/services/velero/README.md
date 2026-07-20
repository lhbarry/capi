# Velero — backup & restore (Services + Workload)

**Reliability:** scheduled backups to S3, immutable options, restore drills.  
Install on **both** EKS clusters (each backs up its own namespaces).

| Cluster | What to protect |
|---------|-----------------|
| **Services** | `argocd`, platform ns (OpenBao, Harbor, Keycloak, … as they land) |
| **Workload** | App namespaces, Knative, Agent ns |

## Layout

| File | Purpose |
|------|---------|
| [VERSIONS.md](VERSIONS.md) | Chart / image pins |
| [install.md](install.md) | Install order + IRSA notes |
| [schedules-services.yaml](schedules-services.yaml) | Daily + weekly Schedule CRs (Services) |
| [schedules-workload.yaml](schedules-workload.yaml) | Daily + weekly Schedule CRs (Workload) |
| [backupstoragelocation.yaml](backupstoragelocation.yaml) | BSL → S3 (template) |
| [restore-drill.md](restore-drill.md) | Quarterly restore procedure |
| [values-example.yaml](values-example.yaml) | Helm values sketch |

## RPO / RTO (aligned with docs/reliability.md)

| Backup | Schedule | Default RPO contribution |
|--------|----------|--------------------------|
| Daily namespace backup | 01:00 UTC | ≤ 24 h |
| Weekly full + volumes | Sunday 03:00 UTC | Long-term retention |

## Prerequisites

- S3 bucket (SSE-KMS), no public access  
- IRSA (or node role — prefer IRSA) for Velero SA on each cluster  
- CSI snapshot CRDs if volume snapshots used  

**Not Flux-wired** until intentional promote.
