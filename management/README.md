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

## Sizing (pending hardware profile)

| Class | vCPU | RAM | Example types |
|-------|-----:|----:|---------------|
| Small (min prod) | 4 | 16 GiB | `m6i.xlarge`, `m7i.xlarge` |
| Medium | 8 | 32 GiB | `m6i.2xlarge`, `m7i.2xlarge` |
| Disk | — | — | gp3 SSD, ≥60–100 GiB root; etcd on SSD |

When the hardware profile lands, record it here and in the ADR.

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
