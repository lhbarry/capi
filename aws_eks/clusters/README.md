# EKS workload clusters (CAPA)

## GitOps only (when enabling)

Applied by Flux Kustomization **`flux-system/aws-eks-clusters`** → Kind → CAPA → AWS.

**Dev mode:** keep `resources: []` in `kustomization.yaml`. Enabling the cluster file **and** pushing to the tracked branch creates real AWS resources (EKS, VPC, NAT, workers).

```bash
# Only when intentionally provisioning:
# 1) Deploy IAM + CMK (aws_iam, aws_eks/kms) if not present
# 2) Set params in kustomization.yaml (AWS_REGION, PUBLIC_API_CIDR)
# 3) Enable: resources: [capi-eks-1.yaml]
# 4) git commit && git push   # ← this is the AWS create path via Flux
```

## Parameters (`kustomization.yaml`)

| Literal | Purpose |
|---------|---------|
| `AWS_REGION` | Region for `AWSManagedControlPlane` |
| `PUBLIC_API_CIDR` | Allowlist for EKS public API (e.g. `x.x.x.x/32`) |

Placeholders in YAML are filled by kustomize **replacements**. SSH keys are intentionally empty (SSM on nodes).

## Substrate hardens (in `capi-eks-1.yaml`)

| Control | Setting |
|---------|---------|
| Control-plane logs | All five → CloudWatch |
| Endpoint | Private + public, `publicCIDRs` allowlist |
| Secrets encryption | `alias/cluster-api-provider-aws-eks-secrets` (deploy `../kms` first) |
| OIDC | `associateOIDCProvider: true` (IRSA-ready) |
| Bastion / SSH | Bastion off; `sshKeyName: ""` |
| Tags | Project / Environment / CostCenter / … |
| Workers | `publicIP: false`; AL2023 `insecureSkipSecretsManager: true` |

## Clusters

| File | Notes |
|------|-------|
| `capi-eks-1.yaml` | EKS CP + CAPA workers, v1.34.1, 2 AZs, WA hardens above |

## IAM / cost / KMS (not Flux)

| Stack / path | When |
|--------------|------|
| `aws_iam/` | CAPA roles (incl. node SSM policy in ec2 stack) |
| `aws_eks/kms/` | CMK before first cluster create |
| `aws_cost/` | Optional monthly budget |
