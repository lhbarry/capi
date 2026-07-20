# SCKE Transformative Architecture

Arch. adaptation from On-Prem to AWS Cloud Services Hosting — **Cluster API + CAPA** → **Amazon EKS**, with a **Services plane** on that cluster.

**Phase:** **Production design** for a **high AWS Well-Architected (WAF) score**, built on a **completed lab foundation** (IAM, EKS scaffold, substrate hardens).

**Docs:** [ARCHITECTURE.md](ARCHITECTURE.md) (§1.1 WAF targets) · [docs/platform-candidates.md](docs/platform-candidates.md) · [docs/architecture.svg](docs/architecture.svg)

## Architecture diagram

<a href="docs/architecture.svg">
  <img src="docs/architecture.svg" alt="SCKE Transformative Architecture — click for full SVG" width="720" />
</a>

**Management:** **SUSE Rancher** on **RKE2** / **Ubuntu latest stable LTS**, **3 × (4 vCPU / 16 GiB / 100 GiB gp3)** ([ADR-001](docs/adr/001-management-cluster-rancher.md) · [`management/`](management/)). Experimental `clusters/capi-mgmt` (Kind) is not production.

## Primary path: EKS + Services plane (production)

| Path | Owns | Apply how |
|------|------|-----------|
| **`aws_eks/`** | CAPA EKS substrate + KMS; **Services** under `aws_eks/services/` | CAPA → AWS; Services via Argo (target) or explicit apply |
| **`aws_iam/`** | CAPA IAM CloudFormation | `aws cloudformation deploy --template-file …` |
| **`aws_cost/`** | Production budget guardrails | CLI deploy — not Flux |

### Services plane

| Industry capability | Team name | Stack |
|---------------------|-----------|--------|
| Continuous delivery (GitOps CD) | CI/CD | Argo CD: **Principal + ApplicationController** (Services), **Agent** (Workload, independent). [`aws_eks/services/argocd/`](aws_eks/services/argocd/) |
| Node autoscaling | Compute | Karpenter — **5 Reserved** services + **5 Reserved** workload + **1.5× worker** headroom; mgmt **3 Reserved**. [`aws_eks/services/karpenter/`](aws_eks/services/karpenter/) |
| Backup & restore (also Workload) | Resilience | Velero |
| Secrets management | Secrets | OpenBao |
| Secrets synchronization | Secrets | External Secrets Operator |
| Database platform | Data | CloudNativePG |
| OCI container registry | Image Proxy | Harbor |
| AuthN/AuthZ proxy | Auth/Auth | OAuth2 Proxy |
| Identity provider (IdP) | ID Federation | Keycloak |
| Telemetry collection | Obs. Infra | OpenTelemetry |
| Observability backend | Observability | Grafana · Loki · Tempo · Mimir (LGTM) |

See [ARCHITECTURE.md §7](ARCHITECTURE.md#7-services-plane).

**Workload plane:** CAPA bootstrap + Karpenter reserved workload nodes + **Argo CD Agent**, **Knative**, **Velero**.

## IAM

All CAPA IAM under **`aws_iam/`** only.

| Stack | Template | Use for EKS |
|-------|----------|-------------|
| `capa-iam-common` | `aws_iam/common.yaml` | Always |
| `capa-iam-eks` | `aws_iam/eks.yaml` | EKS control plane + controller policy |
| `capa-iam-ec2` | `aws_iam/ec2-self-managed.yaml` | Node profile (+ SSM) |

## Secondary: `aws_ec2/`

Self-managed kubeadm path — **not** the production focus; later mirror of this EKS operating model.

## Other paths

| Path | Owns |
|------|------|
| **`clusters/capi-mgmt/`** | Historical / experimental mgmt — **not** production management |
| **`local/`** | Notes, secrets (gitignored) |
| **`.planning/handoffs/`** | Session handoffs |
| **`graphify-out/`** | Knowledge graph (local only) |

## Rules

1. **YAML first** for AWS and platform changes.  
2. CAPA → **AWS**; Services plane (incl. Argo CD, Karpenter) on **EKS**.  
3. **Production WAF targets** in ARCHITECTURE §1.1 — design to those scores.  
4. **Reserved capacity is intentional** (3 / 5 / 5 + 1.5× headroom).  
5. No secrets in git.  
6. Substrate production floor: **3 AZs**, bootstrap **≥2**, hardens on (logging, CMK, OIDC, SSM).  
7. Experimental Flux on Kind is not the production CD story; do not enable cluster resources until an intentional environment promotion.
