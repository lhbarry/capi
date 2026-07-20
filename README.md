# SCKE Transformative Architecture

Arch. adaptation from On-Prem to AWS Cloud Services Hosting — **Cluster API + CAPA** → **Amazon EKS**, with a **Services plane** on that cluster.

**Phase:** **Production design** for a **high AWS Well-Architected (WAF) score**, built on a **completed lab foundation** (IAM, EKS scaffold, substrate hardens).

**Docs:** [ARCHITECTURE.md](ARCHITECTURE.md) (§1.1 WAF targets) · [docs/platform-candidates.md](docs/platform-candidates.md) · [docs/architecture.svg](docs/architecture.svg)

## Architecture diagram

<a href="docs/architecture.svg">
  <img src="docs/architecture.svg" alt="SCKE Transformative Architecture — click for full SVG" width="720" />
</a>

**Management:** **SUSE Rancher** on **RKE2** / **Ubuntu latest stable LTS**, **3 × (4 vCPU / 16 GiB / 100 GiB gp3)** ([ADR-001](docs/adr/001-management-cluster-rancher.md) · [`management/`](management/)). Experimental `clusters/capi-mgmt` (Kind) is not production.

## Three clusters (production)

| Cluster | Path | Apply how |
|---------|------|-----------|
| **1. Management** | [`management/`](management/) | Day-0 CFN + RKE2 + Rancher ([docs/clusters.md](docs/clusters.md)) |
| **2. Services EKS** | [`aws_eks/clusters/services/`](aws_eks/clusters/services/) | CAPA on Management |
| **3. Workload EKS** | [`aws_eks/clusters/workload/`](aws_eks/clusters/workload/) | CAPA on Management |
| Platform installs | [`aws_eks/services/`](aws_eks/services/) (Argo, Karpenter, …) | Onto Services and/or Workload |
| IAM / cost / KMS | `aws_iam/`, `aws_cost/`, `aws_eks/kms/` | CLI CFN when promoting |

### Services plane

| Industry capability | Team name | Stack |
|---------------------|-----------|--------|
| Continuous delivery (GitOps CD) | CI/CD | Argo CD: **Principal + ApplicationController** (Services), **Agent** (Workload, independent). [`aws_eks/services/argocd/`](aws_eks/services/argocd/) |
| Node autoscaling | Compute | **Karpenter on Workload only** (5 Reserved + 1.5× headroom). Services: CAPA **5 Reserved**. Mgmt: **3**. [`aws_eks/services/karpenter/`](aws_eks/services/karpenter/) |
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
2. Provision **Management → Services → Workload** ([docs/provisioning-order.md](docs/provisioning-order.md)).  
3. **Karpenter on Workload only.**  
4. **Production WAF** targets §1.1; score to date §1.2 / [docs/wa-scorecard.md](docs/wa-scorecard.md).  
5. Reserved capacity intentional (mgmt 3 / Services CAPA 5 / Workload Karpenter 5 + headroom).  
6. No secrets in git.  
7. Experimental Kind Flux is not production; keep CAPA `resources: []` until intentional promote.
