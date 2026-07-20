# ADR-001: Management cluster host — SUSE Rancher on 3-node RKE2

**Status:** Accepted (software layer + topology)  
**Date:** 2026-07-20  
**Phase:** Production design (high WAF)

## Context

The management plane runs CAPI/CAPA (and related control tooling) to provision Amazon EKS workload/Services clusters. Capacity is fixed at **3 nodes Reserved**. Lab Kind + Flux is **not** the production product.

## Decision

| Layer | Choice |
|-------|--------|
| **Software** | **SUSE Rancher** (Rancher Manager / **Prime** support already in place) |
| **Kubernetes under Rancher** | **RKE2** HA **upstream** cluster — **3 server nodes** (etcd + control plane; odd number for quorum) |
| **Node count** | **3 Reserved** (matches capacity model) |
| **OS** | **Ubuntu — latest stable release** (LTS track for production) |
| **Node shape** | **4 vCPU / 16 GiB / 100 GiB gp3** |
| **Placement** | AWS EC2, **multi-AZ** (one node per AZ preferred) |
| **Not chosen** | Kind (lab only); bare CAPA-on-EKS without Rancher; SLE Micro / SLES as mgmt OS |

### AMI / OS — **locked**

| Field | Decision |
|-------|----------|
| **OS family** | **Ubuntu** |
| **Release policy** | **Latest stable release** — for production use the current **LTS** from Canonical (server track). As of 2026-07 that is **Ubuntu 24.04 LTS**; when a newer LTS becomes current stable, migrate only after RKE2 matrix certification. |
| **AMI source** | **Official Canonical** Ubuntu Server AMI (free; no mandatory OS license). Do **not** use third-party “Ubuntu + support” Marketplace images unless explicitly approved. |
| **Rejected OS** | **SLE Micro**, SLES (as mgmt host OS) — optional later only if requirements change; not the design default |
| **Also avoid** | Amazon Linux 2 / 2023 as primary RKE2/Rancher OS |

**Rule:** Before baking an AMI ID into IaC, confirm the chosen Ubuntu LTS appears on the [RKE2 support matrix](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/) for the **RKE2 minor** used with the pinned Rancher version. Re-check when bumping Ubuntu LTS or RKE2.

**Security process (Ubuntu):** golden AMI / rebuild nodes (minimize hand `apt` drift); keep AppArmor enabled; SSM over SSH; EBS encryption; planned reboot window for kernel security updates. Rancher **Prime** covers Rancher stack; OS security lifecycle is Canonical/Ubuntu (optional Ubuntu Pro for expanded maintenance).

### Instance sizing — **locked production profile**

**Accepted node shape (per management node):** **4 vCPU / 16 GiB RAM / 100 GiB gp3 SSD**  
**Count:** **3** RKE2 server nodes, multi-AZ  

Aligned with Rancher **Small** RKE2 upstream floor ([install requirements](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes)): 4 vCPU / **16 GB** RAM. Disk **100 GiB gp3** meets SSD/etcd guidance ([RKE2](https://docs.rke2.io/install/requirements), Rancher disk section).

| Spec | Locked value | AWS notes |
|------|--------------|-----------|
| vCPU | **4** | — |
| RAM | **16 GiB** | — |
| Disk | **100 GiB gp3** SSD | Root EBS; baseline gp3 IOPS |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` | Prefer **M** over **T** (no CPU credits for etcd/Rancher) |
| Topology | **3** nodes, multi-AZ | One node per AZ when possible |

**Rejected candidate:** `4 / 8 / 100` — 8 GiB meets RKE2-only recommend but is **below** Rancher Small (16 GB).

Reference Rancher RKE2 upstream table (context only; we lock Small):

| Class | Max clusters | Max nodes | vCPU | RAM |
|-------|-------------:|----------:|-----:|----:|
| **Small (ours)** | 150 | 1500 | **4** | **16 GB** |
| Medium | 300 | 3000 | 8 | 32 GB |
| Large | 500 | 5000 | 16 | 64 GB |

Scale to Medium/Large only if managed fleet or CAPA load exceeds Small assumptions.

### Network / HA (production)

- **3 RKE2 server nodes** across **3 AZs**
- **NLB** (or equivalent) for Kubernetes API (`6443`) and Rancher UI/API (`443`)
- Security groups per [RKE2 port matrix](https://docs.rke2.io/install/requirements) (6443, 9345, 2379–2381, CNI ports, etc.)
- Private subnets preferred; bastion/SSM for admin access (no standing SSH keys in design)

### What runs where

```text
Management (3× EC2, RKE2 + Rancher)
  ├── Rancher Manager
  ├── CAPI + CAPA (cluster lifecycle → aws_eks/)
  └── (optional) GitOps agent for management desired state

Downstream EKS (Services + Workload)
  ├── Argo CD, Karpenter, platform services
  └── Application workloads
```

## Alternatives considered

| Option | Why not |
|--------|---------|
| Kind on a laptop/VM | Lab only; fails production REL/OPS |
| EKS as management cluster without Rancher | Valid AWS-native path; **rejected** — org chose **SUSE Rancher** as software layer |
| K3s for Rancher | Acceptable for small; **RKE2 preferred** for production HA Rancher |
| **SLE Micro** as mgmt OS | Strong immutable defaults; **rejected** for this design — Ubuntu latest stable chosen (on-prem parity, no OS license fee, team familiarity). Rancher **Prime** already covers Rancher support without requiring Micro. |
| SLES as mgmt OS | Same as Micro for commercial SUSE OS path; not selected |

## Consequences

- **OS = Ubuntu latest stable (LTS track)**; pin concrete AMI ID (region) at deploy; no SUSE OS PAYG/BYOS for management nodes.
- **Rancher Prime** remains the commercial support path for Rancher; OS support is Canonical (optional Ubuntu Pro).
- Node shape **4/16/100 gp3** × 3 multi-AZ is locked with Ubuntu.
- CAPA credentials and Rancher cloud credentials for AWS need a production IAM design (next slices).
- Experimental `clusters/capi-mgmt` remains historical; production mgmt lives under `management/`.

## Open items

1. ~~Hardware profile~~ → **locked 4 / 16 / 100 gp3**  
2. ~~OS family~~ → **Ubuntu latest stable (LTS)**  
3. Pin **Rancher version** + matching **RKE2 version** → re-check Ubuntu LTS on matrix → lock **region AMI ID**  
4. Exact instance type (`m7i.xlarge` vs `m6i.xlarge`, etc.)  
5. Day-0 bootstrap procedure (Terraform/CFN/Ansible + RKE2 install on Ubuntu)  
6. Where CAPI/CAPA install lands relative to Rancher (local cluster apps)

## References

- [RKE2 requirements](https://docs.rke2.io/install/requirements)  
- [RKE2 HA](https://docs.rke2.io/install/ha)  
- [RKE2 for Rancher](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-cluster-setup/rke2-for-rancher)  
- [Rancher installation requirements](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements)  
- [RKE2 support matrix (pick version)](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/)  
- [Rancher support matrix (pick version)](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/)  
