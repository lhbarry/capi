# Services plane (on EKS)

Platform capabilities that run **on the CAPA-provisioned EKS cluster** (Services plane in [ARCHITECTURE.md](../../ARCHITECTURE.md)).

**Not Flux-wired today.** Flux only reconciles `aws_eks/clusters/`. Enabling these manifests is a deliberate apply (Argo CD later, or kubectl) — safe in pure-dev.

## Layout

| Path | Purpose |
|------|---------|
| [`karpenter/`](karpenter/) | Node autoscaling (Compute) — NodePools, EC2NodeClass, reserved capacity, headroom |
| (future) | Argo CD, Velero, secrets, IdP, Harbor, CNPG, OTel, LGTM |

## Capacity model (summary)

| Domain | Reservation | How |
|--------|-------------|-----|
| **Management** cluster | **3 nodes Reserved** | Fixed capacity target for the management plane (host TBD) |
| **Services** plane | **5 nodes Reserved** | Karpenter NodePool + overprovisioning pause pods |
| **Workload** plane | **5 nodes Reserved** | Karpenter NodePool + overprovisioning pause pods |
| **Headroom** (waiting) | **≥ 1.5 × one worker** CPU + RAM free | Cluster-wide overprovisioning (preemptible) |

Reference worker size (CAPA bootstrap / NodePool family): **`t3.large`** → 2 vCPU, 8 GiB → headroom **3 vCPU, 12 GiB**.

Details: [`karpenter/capacity.md`](karpenter/capacity.md).
