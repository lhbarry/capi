# capi — CAPI / CAPA lab (GitOps)

Prove and document creating/managing Kubernetes on AWS with **Cluster API + CAPA**, driven from this GitHub repo via **Kind** (management plane).

```text
GitHub (lhbarry/capi)
    │
    ├── Flux on Kind (capi-mgmt)  →  CAPI/CAPA objects
    │                                    │
    │                                    └── CAPA  →  AWS (EC2 or EKS)
    │
    └── aws cloudformation deploy --template-file aws_iam/*.yaml  →  IAM
```

## Top-level layout

| Path | Owns | Apply how |
|------|------|-----------|
| **`aws_iam/`** | CAPA IAM CloudFormation (shared) | `aws cloudformation deploy --template-file …` |
| **`aws_ec2/`** | Self-managed kubeadm CAPA cluster YAML + workload addons | Flux / `kubectl` on Kind; addons on workload kubeconfig |
| **`aws_eks/`** | EKS-oriented CAPA cluster YAML | Same pattern as `aws_ec2` (scaffold) |
| **`clusters/capi-mgmt/`** | Flux bootstrap, Weave UI, Flux Kustomizations | Flux self-manages after bootstrap |
| **`local/`** | Process notes, secrets (gitignored) | Never commit |
| **`.planning/handoffs/`** | Session handoffs | Git-tracked |
| **`graphify-out/`** | Knowledge graph artifacts | **Local only** (gitignored) |

## IAM (one place only)

All CAPA IAM lives under **`aws_iam/`** — not under `aws_ec2/` or `aws_eks/`.

| Stack | Template | Use |
|-------|----------|-----|
| `capa-iam-common` | `aws_iam/common.yaml` | Always |
| `capa-iam-ec2` | `aws_iam/ec2-self-managed.yaml` | `aws_ec2` path |
| `capa-iam-eks` | `aws_iam/eks.yaml` | `aws_eks` path |

See [`aws_iam/README.md`](aws_iam/README.md).

## Workload paths (two Flux jobs on Kind)

| Job (Flux Kustomization) | Git path | Cluster tree |
|--------------------------|----------|--------------|
| `aws-ec2-clusters` | `./aws_ec2/clusters` | [`aws_ec2/`](aws_ec2/) self-managed kubeadm |
| `aws-eks-clusters` | `./aws_eks/clusters` | [`aws_eks/`](aws_eks/) EKS control plane |

Job CRs live in git: `clusters/capi-mgmt/jobs/`. **No manual `kubectl apply` to Kind or AWS.** Push to `main` is the implement path (subject to each job’s `spec.suspend`).

## Rules

1. **YAML first** for anything that creates/changes AWS.  
2. Flux applies to **Kind**; CAPA reconciles to **AWS**.  
3. No secrets in git.  
4. Lab network cost control for EC2 path: single AZ / single NAT (`availabilityZoneUsageLimit: 1`).
