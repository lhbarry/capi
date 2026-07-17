# capi — CAPA → Amazon EKS (GitOps lab)

Prove and document creating/managing **Amazon EKS** with **Cluster API + CAPA**, driven from this GitHub repo via **Kind** (management plane).

**Architecture (design + diagram):** [ARCHITECTURE.md](ARCHITECTURE.md) · [docs/architecture.svg](docs/architecture.svg)

```text
GitHub (this repo)
    │
    ├── Flux on Kind (capi-mgmt)  →  CAPA objects (aws_eks/)
    │                                    │
    │                                    └── CAPA  →  Amazon EKS + EC2 workers
    │                                                      │
    │                                                      └── Services plane (on EKS)
    │                                                            Argo CD Agent · DB · registry
    │                                                            IdP · auth proxy · OTel · LGTM
    │
    ├── Argo CD Principal (hub)  ←→  Agent on EKS   →  services + apps
    │
    └── aws cloudformation deploy --template-file aws_iam/*.yaml  →  IAM
```

## Primary path: EKS + Services plane

| Path | Owns | Apply how |
|------|------|-----------|
| **`aws_eks/`** | EKS CAPA cluster YAML (`AWSManagedControlPlane`, workers) | Flux job `aws-eks-clusters` → Kind → CAPA → AWS |
| **`aws_iam/`** | CAPA IAM CloudFormation | `aws cloudformation deploy --template-file …` |
| **`clusters/capi-mgmt/`** | Flux bootstrap, Weave UI, Flux jobs | Flux self-manages after bootstrap |

Job CR: [`clusters/capi-mgmt/jobs/aws-eks-clusters.yaml`](clusters/capi-mgmt/jobs/aws-eks-clusters.yaml) → `./aws_eks/clusters`.

**No manual `kubectl apply` of cluster CRs.** Push to `main` is the implement path (respect `spec.suspend`).

### Services plane (on EKS — architecture target)

| Industry capability | Team name | Stack |
|---------------------|-----------|--------|
| Continuous delivery (GitOps CD) | CI/CD | Argo CD **Principal** + **Agent** |
| Database platform | Data | CloudNativePG |
| OCI container registry | Image Proxy | Harbor |
| AuthN/AuthZ proxy | Auth/Auth | OAuth2 Proxy |
| Identity provider (IdP) | ID Federation | Keycloak |
| Telemetry collection | Obs. Infra | OpenTelemetry |
| Observability backend | Observability | Grafana · Loki · Tempo · Mimir (LGTM) |

**GitOps split:** Flux on Kind = cluster lifecycle (CAPA). Argo CD = services + apps on EKS.

See [ARCHITECTURE.md §7](ARCHITECTURE.md#7-services-plane).

## IAM (one place only)

All CAPA IAM lives under **`aws_iam/`** — not under `aws_eks/`.

| Stack | Template | Use for EKS |
|-------|----------|-------------|
| `capa-iam-common` | `aws_iam/common.yaml` | Always |
| `capa-iam-eks` | `aws_iam/eks.yaml` | EKS control plane + controller policy |
| `capa-iam-ec2` | `aws_iam/ec2-self-managed.yaml` | Node instance profile (current worker flavor) |

See [`aws_iam/README.md`](aws_iam/README.md).

## Secondary: `aws_ec2/`

Self-managed kubeadm path exists under [`aws_ec2/`](aws_ec2/) but is **not** the architecture focus. It will be reshaped as a **clone of the EKS operating model** later.

## Other paths

| Path | Owns |
|------|------|
| **`local/`** | Process notes, secrets (gitignored) — never commit |
| **`.planning/handoffs/`** | Session handoffs |
| **`graphify-out/`** | Knowledge graph artifacts (gitignored) |

## Rules

1. **YAML first** for anything that creates/changes AWS.  
2. Flux applies to **Kind**; CAPA reconciles to **AWS**; Argo CD delivers **services/apps** to EKS.  
3. No secrets in git.  
4. EKS lab cost floor: **2 AZs / 2 NATs** (`availabilityZoneUsageLimit: 2` on the managed control plane VPC).
