# Management plane — SUSE Rancher (production)

**Decision:** [docs/adr/001-management-cluster-rancher.md](../docs/adr/001-management-cluster-rancher.md)

| Item | Value |
|------|--------|
| Software | **SUSE Rancher** on **RKE2** |
| Nodes | **3 Reserved** (all RKE2 **server** nodes for etcd quorum) |
| **Node shape** | **4 vCPU / 16 GiB RAM / 100 GiB gp3 SSD** |
| Cloud | AWS EC2, multi-AZ |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` |
| Labels | `capacity.scke.io/reservation=reserved`, `capacity.scke.io/plane=management` |

## AMI recommendation (summary)

| Preference | AMI / OS |
|------------|----------|
| **Default** | **SLE Micro** (SUSE public cloud / Marketplace) x86_64 HVM |
| Alt SUSE | SLES 15 SP (matrix-current SP) |
| On-prem parity | Ubuntu **24.04** LTS Canonical AMI **if** matrix-certified for pinned RKE2 |
| Fallback | Ubuntu **22.04** LTS |
| Avoid | Amazon Linux as primary RKE2/Rancher OS |

Re-validate OS against the RKE2 support matrix for the **exact** RKE2 minor used by the pinned Rancher version before locking an AMI ID.

## Sizing — locked

| Spec | Value | Source |
|------|--------|--------|
| Nodes | **3** | Production HA / etcd quorum |
| vCPU | **4** | Rancher Small RKE2 upstream |
| RAM | **16 GiB** | Rancher Small (not 8 GiB) |
| Disk | **100 GiB gp3** SSD | SSD required for etcd; size for IOPS |
| Avoid | `t3`/`t3a` | CPU credits vs etcd/Rancher |

Official: [Rancher install requirements](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes) · [RKE2 requirements](https://docs.rke2.io/install/requirements)

## Layout (to grow)

| Path | Purpose |
|------|---------|
| `README.md` | This file |
| (future) `rke2/` | Node config, install notes |
| (future) `rancher/` | Helm values / app install |
| (future) `infra/` | VPC, NLB, ASG/EC2, IAM (YAML/CFN) |

## Relation to rest of repo

- **Downstream clusters:** CAPA → EKS in `aws_eks/` (Services + Workload)  
- **Lab Kind path:** `clusters/capi-mgmt/` — historical only  
- **Capacity model:** `aws_eks/services/karpenter/capacity.md` (mgmt 3 Reserved)  
