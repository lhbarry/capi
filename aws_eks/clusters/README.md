# EKS workload clusters (CAPA)

## GitOps only

Applied by Flux Kustomization **`flux-system/aws-eks-clusters`** → Kind → CAPA → AWS.

```bash
# 1) Set params in kustomization.yaml (configMapGenerator literals)
# 2) Enable: resources: [capi-eks-1.yaml]
# 3) git commit && git push
```

## Parameters (`kustomization.yaml`)

| Literal | Purpose |
|---------|---------|
| `AWS_REGION` | Region for `AWSManagedControlPlane` |
| `AWS_SSH_KEY_NAME` | EC2 key pair for worker nodes |

Placeholders in YAML are filled by kustomize **replacements**.

## Clusters

| File | Notes |
|------|-------|
| `capi-eks-1.yaml` | EKS CP + CAPA workers, v1.34.1, 2 AZs (EKS minimum), AL2023 AMI lookup |

## IAM

`capa-iam-common` + `capa-iam-eks` (+ `capa-iam-ec2` for worker instance profile). See `aws_iam/`.
