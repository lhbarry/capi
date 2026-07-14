# aws_eks — CAPA → Amazon EKS (GitOps)

Declarative CAPA manifests for **EKS managed control plane** (+ EC2 workers in current flavor).

## Tenant (project rule)

| Rule | Practice |
|------|----------|
| All desired state in YAML | Under `aws_eks/` (and shared `aws_iam/`) |
| Implemented only from git | Push to `main` → Flux reconciles Kind |
| No manual apply | No `kubectl apply` / no console for cluster create |
| Kind is management only | Flux job `aws-eks-clusters` applies CRs to Kind; CAPA talks to AWS |

## Flux job

| Flux Kustomization | Path | Effect |
|--------------------|------|--------|
| `flux-system/aws-eks-clusters` | `./aws_eks/clusters` | Apply EKS CAPA CRs to Kind |

Defined in `clusters/capi-mgmt/jobs/aws-eks-clusters.yaml` (GitOps of the GitOps job itself).

## IAM

`aws_iam/`: stacks **`capa-iam-common`** + **`capa-iam-eks`** (+ **`capa-iam-ec2`** for worker instance profile used by this flavor).

## Layout

| Path | Purpose |
|------|---------|
| `clusters/` | CAPA EKS cluster manifests (Flux-synced) |
| `clusters/capi-eks-1.yaml` | First lab EKS cluster |

## Parallel path

EC2 self-managed: `aws_ec2/` + Flux job `aws-ec2-clusters`.
