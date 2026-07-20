# Reliability design (REL)

**Goal:** Production design score **≥ 4.0** for Reliability.  
**Related:** [wa-scorecard.md](wa-scorecard.md) · [provisioning-order.md](provisioning-order.md) · [clusters.md](clusters.md)

## Architecture HA (already locked)

| Layer | Design |
|-------|--------|
| Management | **3** RKE2 servers, multi-AZ, etcd quorum |
| Services EKS | **3 AZ** VPC, **5** CAPA Reserved nodes, private EKS CP (AWS-managed multi-AZ) |
| Workload EKS | **3 AZ**, bootstrap **2** + Karpenter **5 Reserved** + **1.5×** headroom |
| Blast radius | Separate Services vs Workload clusters; Agent independent of Principal |
| Change path | Git → CAPA order Management → Services → Workload |

## RTO / RPO targets (production design)

| Scope | RPO | RTO | Mechanism |
|-------|-----|-----|-----------|
| Workload apps (stateless) | ≤ 1 h (git) | ≤ 1 h | Redeploy via Argo Agent from git |
| Workload / Services PVC + ns | ≤ 24 h | ≤ 4 h | **Velero** scheduled backup → S3 |
| EKS control plane | N/A (managed) | AWS EKS SLA | Managed multi-AZ CP |
| Management etcd / Rancher | ≤ 24 h | ≤ 4 h | RKE2 etcd snapshots + Rancher backup |
| Full region loss | Deferred | Deferred | Single-region unless business requires multi-region |

## Failure modes & design response

| Failure | Expected behavior |
|---------|-------------------|
| 1 AZ loss | Remaining AZs absorb; EKS CP stays up; CAPA/Karpenter replace nodes |
| 1 Services node loss | CAPA MD 5 with multi-AZ spread; Argo Principal HA replicas |
| 1 Workload node loss | Karpenter + headroom; Agent continues |
| Principal down | Workload **Agent operates independently** |
| Git unavailable | No new desired state; running apps continue; restore from last known |
| CAPA controller down on Management | Existing clusters keep running; no create/update until CAPA restored |
| Accidental delete ns | Velero restore drill path |

## Control catalog

| Control | Path |
|---------|------|
| Velero install + schedules | [`aws_eks/services/velero/`](../aws_eks/services/velero/) |
| Restore drill runbook | [`aws_eks/services/velero/restore-drill.md`](../aws_eks/services/velero/restore-drill.md) |
| CloudWatch alarms | [`aws_reliability/alarms.yaml`](../aws_reliability/alarms.yaml) |
| PDBs / topology | [`aws_eks/reliability/`](../aws_eks/reliability/) |
| Management etcd snapshots | [`management/reliability.md`](../management/reliability.md) |
| Service quotas | [`aws_reliability/quotas.md`](../aws_reliability/quotas.md) |

## Explicit non-goals (now)

- Multi-region active-active  
- Zero RPO for all state  
- Chaos Mesh mandatory in day-0 (optional later)  
