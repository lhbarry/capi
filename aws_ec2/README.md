# aws_ec2 — CAPA self-managed (kubeadm on EC2)

Git-tracked **cluster and workload addon** manifests for CAPA **self-managed** clusters (EC2 instances + kubeadm). Not the place for shared IAM.

## IAM

Shared CAPA IAM CloudFormation lives only in **[`aws_iam/`](../aws_iam/)**.

For this path deploy:

1. `capa-iam-common` ← `aws_iam/common.yaml`  
2. `capa-iam-ec2` ← `aws_iam/ec2-self-managed.yaml`

## Layout

| Path | Purpose |
|------|---------|
| `clusters/` | CAPI/CAPA objects (`Cluster`, `AWSCluster`, machines, …) |
| `clusters/addons/` | Workload CNI/CCM (apply with **workload** kubeconfig) |
| `clusters/kustomization.yaml` | Flux → Kind path (`capi-lab-1.yaml` only) |

## Apply flow

```text
aws_iam/*          →  CloudFormation (IAM)
aws_ec2/clusters/* →  Kind (Flux Kustomization aws-ec2-clusters)
                   →  CAPA → AWS EC2 / VPC / NLB / …
addons/*           →  workload API after cluster is up
```

## Rules

1. No blind AWS mutations; edit YAML here (or `aws_iam/`), then apply from file.  
2. Flux must not apply `addons/` onto Kind — only CAPI CRs.  
3. No secrets in git.  
4. Lab: `availabilityZoneUsageLimit: 1` → one NAT.
