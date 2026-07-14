# aws_eks — CAPA → EKS (GitOps)

Git-tracked resources for **EKS** workload clusters managed by CAPA on Kind.

## Status

Scaffold only. Cluster manifests not generated yet.

## Prerequisites

1. Kind management cluster + CAPA controllers (`capi-mgmt`).  
2. IAM from **[`aws_iam/`](../aws_iam/)** only: stacks **`capa-iam-common`** + **`capa-iam-eks`**.  
3. YAML-first: generate/edit under `aws_eks/clusters/`, then apply via Flux or `kubectl` on Kind.

IAM is **not** stored under `aws_eks/`.

## Layout (planned)

| Path | Purpose |
|------|---------|
| `README.md` | This file |
| `clusters/` | CAPA EKS `Cluster` / managed control plane / machine pool YAML |

## Principles

Same as `aws_ec2/`: GitHub → Kind (Flux) → CAPA → AWS. No secrets in git.
