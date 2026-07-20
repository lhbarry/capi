# ADR-001: Management cluster host — SUSE Rancher on 3-node RKE2

**Status:** Accepted (software layer + topology)  
**Date:** 2026-07-20  
**Phase:** Production design (high WAF)

## Context

The management plane runs CAPI/CAPA (and related control tooling) to provision Amazon EKS workload/Services clusters. Capacity is fixed at **3 nodes Reserved**. Lab Kind + Flux is **not** the production product.

## Decision

| Layer | Choice |
|-------|--------|
| **Software** | **SUSE Rancher** (Rancher Manager) as the management-plane control UI/API and multi-cluster manager |
| **Kubernetes under Rancher** | **RKE2** HA **upstream** cluster — **3 server nodes** (etcd + control plane; odd number for quorum) |
| **Node count** | **3 Reserved** (matches capacity model) |
| **Placement** | AWS EC2, **multi-AZ** (one node per AZ preferred) |
| **Not chosen** | Kind (lab only); bare CAPA-on-EKS without Rancher; self-managed kubeadm without Rancher |

### AMI / OS (recommended default — confirm against support matrix at pin time)

| Rank | OS / AMI source | When to use |
|-----:|-----------------|-------------|
| **1 (default)** | **SLE Micro** (SUSE Linux Enterprise Micro) — AWS Marketplace / SUSE public cloud AMI, x86_64, HVM, EBS | Best alignment with **SUSE Rancher + RKE2** support and SUSE commercial support path; immutable OS fit for control-plane nodes |
| **2** | **SLES 15 SP** (latest SP on RKE2 matrix) — SUSE AMI | Prefer if you need full SLES tooling vs Micro’s immutable model |
| **3** | **Ubuntu 24.04 LTS** — official Canonical AWS AMI | On-prem parity; only if the **exact** RKE2 + Rancher versions you pin list 24.04 as supported |
| **4 (fallback)** | **Ubuntu 22.04 LTS** — Canonical AMI | If 24.04 is missing from the matrix for your pin |
| **Avoid for mgmt** | Amazon Linux 2 / 2023 as primary Rancher/RKE2 OS | Weaker first-class support history for RKE2; not SUSE’s validated path |

**Rule:** Before baking an AMI ID into IaC, open the [RKE2 support matrix](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/) for the **RKE2 minor** shipped with the chosen Rancher version and confirm the OS row. Also check the [Rancher support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/) for that Rancher release.

### Instance sizing (verified against upstream docs, 2026-07-20)

Two different floors apply; **do not confuse them**:

| Layer | Source | Min / recommend |
|-------|--------|-----------------|
| **RKE2 only** (Kubernetes underlay) | [RKE2 requirements](https://docs.rke2.io/install/requirements) | Min **2 vCPU / 4 GB**; recommend **≥ 4 vCPU / 8 GB**; **SSD** for etcd |
| **Rancher on RKE2** (upstream / local cluster) | [Rancher installation requirements — RKE2](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements#rke2-kubernetes) | Production HA **≥ 3 nodes**; **Small = 4 vCPU / 16 GB per node** |

Rancher official RKE2 upstream table (per node):

| Managed fleet (approx.) | Max clusters | Max nodes | vCPU | RAM |
|-------------------------|-------------:|----------:|-----:|----:|
| Small | 150 | 1500 | **4** | **16 GB** |
| Medium | 300 | 3000 | **8** | **32 GB** |
| Large | 500 | 5000 | **16** | **64 GB** |

Disk (Rancher): **SSD always**; on cloud use size that unlocks adequate IOPS; consider dedicated etcd volume at scale.

#### Candidate profile review: `4 vCPU / 8 GiB / 100 GiB disk`

| Spec | Verdict | Notes |
|------|---------|--------|
| **4 vCPU** | OK for Small | Matches Rancher Small CPU and RKE2 “recommend 4” |
| **8 GiB RAM** | **Below Rancher Small** | Meets RKE2-only recommend (8 GB); **half** of Rancher Small (**16 GB**). Not production-aligned for Rancher Manager + CAPA |
| **100 GiB disk** | OK if **SSD (gp3)** | Good root size; Rancher requires SSD for etcd performance |

**Adapted production profile (recommended):**

| Spec | Value | AWS example |
|------|-------|-------------|
| vCPU | **4** | — |
| RAM | **16 GiB** (not 8) | — |
| Disk | **100 GiB gp3** SSD (3000+ IOPS baseline) | Root EBS |
| Instance | `m6i.xlarge` / `m7i.xlarge` / `m5.xlarge` | Prefer **M** over **T** (no credit exhaustion for etcd/Rancher) |
| Count / AZ | **3** servers, multi-AZ | One per AZ when possible |

If hardware is hard-capped at **8 GiB**, options are: (a) accept **non-production / very small** Rancher footprint and monitor pressure, or (b) use **K3s** upstream table (still **4 / 16 GB** for Small) — still not 8 GiB. **Do not plan production Rancher HA at 8 GiB/node.**

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
| Ubuntu-only because on-prem is 24.04 | Fine as rank 3 if matrix allows; **SLE Micro** preferred for SUSE stack support on AWS |

## Consequences

- Management AMI and instance type become **first-class production parameters** (document AMI ID / SSM parameter once chosen).
- SUSE subscription / Marketplace product choice (BYOS vs PAYG) must be settled for SLE Micro/SLES.
- CAPA credentials and Rancher cloud credentials for AWS need a production IAM design (next slices).
- Experimental `clusters/capi-mgmt` remains historical; production mgmt lives under a new tree (e.g. `management/`).

## Open items

1. Exact **hardware profile** → pick instance type + disk from sizing table  
2. Pin **Rancher version** + matching **RKE2 version** → re-check OS matrix → lock **AMI ID**  
3. BYOS vs PAYG for SUSE images  
4. Day-0 bootstrap procedure (Terraform/CFN/Ansible + RKE2 install)  
5. Where CAPI/CAPA install lands relative to Rancher (local cluster apps)

## References

- [RKE2 requirements](https://docs.rke2.io/install/requirements)  
- [RKE2 HA](https://docs.rke2.io/install/ha)  
- [RKE2 for Rancher](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-cluster-setup/rke2-for-rancher)  
- [Rancher installation requirements](https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-requirements)  
- [RKE2 support matrix (pick version)](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/)  
- [Rancher support matrix (pick version)](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/)  
