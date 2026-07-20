# Management plane — SUSE Rancher (production)

**Decision:** [docs/adr/001-management-cluster-rancher.md](../docs/adr/001-management-cluster-rancher.md)

| Item | Value |
|------|--------|
| Software | **SUSE Rancher** on **RKE2** |
| Nodes | **3 Reserved** (all RKE2 **server** nodes for etcd quorum) |
| Cloud | AWS EC2, multi-AZ |
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

## Sizing (verified)

Official sources:

- [Rancher install requirements (RKE2 upstream)](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes) — **Small = 4 vCPU / 16 GB** per node, **≥3 nodes** for production  
- [RKE2 requirements](https://docs.rke2.io/install/requirements) — min 2/4 GB, recommend **4 / 8 GB**; SSD for etcd  

### Proposed profile check: 4 vCPU / 8 GiB / 100 GiB

| Spec | vs RKE2 | vs Rancher Small | Action |
|------|---------|------------------|--------|
| 4 vCPU | OK | OK | Keep |
| 8 GiB RAM | OK (recommend) | **Short 8 GB** (need 16) | **Raise to 16 GiB** |
| 100 GiB disk | OK if SSD | OK if SSD | Keep as **gp3** |

### Locked production target (adapted)

| Spec | Value |
|------|--------|
| Nodes | **3** RKE2 servers (Reserved) |
| vCPU | **4** |
| RAM | **16 GiB** |
| Disk | **100 GiB gp3** SSD |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` |
| Avoid | `t3`/`t3a` for etcd+Rancher (CPU credits) |

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
