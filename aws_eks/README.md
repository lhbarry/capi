# aws_eks — CAPA → Amazon EKS

Declarative CAPA manifests for **EKS managed control plane** (+ EC2 workers in current flavor).

**Platform architecture:** [ARCHITECTURE.md](../ARCHITECTURE.md) · [docs/architecture.svg](../docs/architecture.svg)

## Tenant (project rule)

| Rule | Practice |
|------|----------|
| All desired state in YAML | Under `aws_eks/` (and shared `aws_iam/`) |
| CAPA owns AWS lifecycle | Controllers reconcile CAPA CRs → EKS / VPC / workers |
| Management host | **TBD** (not fixed in architecture) |
| No secrets in git | Placeholders / local-only config |

## IAM

`aws_iam/`: stacks **`capa-iam-common`** + **`capa-iam-eks`** (+ **`capa-iam-ec2`** for worker instance profile used by this flavor).

## Layout

| Path | Purpose |
|------|---------|
| `clusters/` | CAPA EKS cluster manifests |
| `clusters/capi-eks-1.yaml` | First lab EKS cluster |

## Parallel path

EC2 self-managed: [`aws_ec2/`](../aws_ec2/) — secondary; will mirror this model later.

## Note

`clusters/capi-mgmt/` may contain experimental Flux/Kind wiring used in the lab. That is **not** the architectural management plane — see [ARCHITECTURE.md](../ARCHITECTURE.md).
