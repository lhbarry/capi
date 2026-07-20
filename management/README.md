# Management plane — SUSE Rancher (production)

**Decision:** [docs/adr/001-management-cluster-rancher.md](../docs/adr/001-management-cluster-rancher.md)

| Item | Value |
|------|--------|
| Software | **SUSE Rancher** on **RKE2** (**Prime** support in place) |
| Nodes | **3 Reserved** (all RKE2 **server** nodes) |
| **OS** | **Ubuntu — latest stable release** (LTS track; currently **24.04 LTS**) |
| **AMI** | Official **Canonical** Ubuntu Server (no OS license fee) |
| **Node shape** | **4 vCPU / 16 GiB RAM / 100 GiB gp3 SSD** |
| Cloud | AWS EC2, multi-AZ |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` |
| Labels | `capacity.scke.io/reservation=reserved`, `capacity.scke.io/plane=management` |

## OS policy

1. Track **Ubuntu latest stable** for production as the current **LTS** (not interim non-LTS).  
2. At image bake / deploy, resolve the **Canonical AMI ID** for that LTS in the target region.  
3. Confirm the LTS version is listed on the [RKE2 support matrix](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/) for the pinned RKE2 minor.  
4. When Canonical ships a **new LTS**, do not auto-jump until matrix + test pass.

**Not used for mgmt:** SLE Micro, SLES, Amazon Linux (as primary RKE2 OS).

## Sizing — locked

| Spec | Value |
|------|--------|
| Nodes | **3** |
| vCPU | **4** |
| RAM | **16 GiB** |
| Disk | **100 GiB gp3** SSD |
| Avoid | `t3`/`t3a` |

## Layout (to grow)

| Path | Purpose |
|------|---------|
| `README.md` | This file |
| (future) `rke2/` | Node config, install notes (Ubuntu) |
| (future) `rancher/` | Helm values / app install |
| (future) `infra/` | VPC, NLB, EC2, IAM (YAML/CFN) |

## Relation to rest of repo

- **Downstream clusters:** CAPA → EKS in `aws_eks/` (Services + Workload; AL2023 workers)  
- **Lab Kind path:** `clusters/capi-mgmt/` — historical only  
- **Capacity model:** `aws_eks/services/karpenter/capacity.md` (mgmt 3 Reserved)  
