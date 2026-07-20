# EKS clusters (CAPA) — production design

## Apply path

Flux Kustomization **`flux-system/aws-eks-clusters`** may track this directory on experimental Kind. **Production CD** is Argo CD on the Services plane (design). Keep `resources: []` until an intentional promotion creates AWS.

```bash
# Intentional provision only:
# 1) Deploy IAM + aws_eks/kms CMK
# 2) Set AWS_REGION + PUBLIC_API_CIDR in kustomization.yaml
# 3) resources: [capi-eks-1.yaml]
# 4) Apply via chosen control path (not casual push to experimental Flux)
```

## Parameters

| Literal | Purpose |
|---------|---------|
| `AWS_REGION` | `AWSManagedControlPlane` region |
| `PUBLIC_API_CIDR` | EKS public API allowlist (`x.x.x.x/32`) until private-only |

SSH keys intentionally empty (SSM).

## Production baseline (`capi-eks-1.yaml`)

| Control | Value |
|---------|--------|
| AZs | **3** |
| Bootstrap workers | **2** (system HA) |
| CP logs | All five → CloudWatch |
| Endpoint | Private + public CIDR allowlist |
| Encryption | CMK alias (deploy `../kms` first) |
| OIDC | On (IRSA/Pod Identity) |
| SSH / bastion | Off |
| Tags | `Environment=production`, `CostCenter=scke` |

App/platform capacity: **Karpenter** Reserved 5+5 + 1.5× headroom — [`../services/karpenter/`](../services/karpenter/).

## IAM

`capa-iam-common` + `capa-iam-eks` + `capa-iam-ec2` (node profile + SSM).
