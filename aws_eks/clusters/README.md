# EKS workload clusters (CAPA)

## GitOps only

Manifests here are applied by Flux Kustomization **`flux-system/aws-eks-clusters`** → Kind → CAPA → AWS.

```bash
# Correct: edit YAML, commit, push
git add aws_eks/clusters && git commit && git push

# Wrong: kubectl apply -f ... against Kind or AWS
```

## Clusters

| Name | File | Flavor | Notes |
|------|------|--------|-------|
| `capi-eks-1` | `capi-eks-1.yaml` | `eks` (EKS CP + CAPA `AWSMachine` workers) | v1.34.1, 1 worker `t3.large`, 1 AZ / 1 NAT |

Not using `eks-managedmachinepool` until CAPA webhook for `AWSManagedMachinePool` is fixed on this mgmt cluster.

## IAM

Requires `capa-iam-common` + `capa-iam-eks` (+ `capa-iam-ec2` nodes profile if workers use `nodes.*` instance profile — yes for this flavor).

See `aws_iam/README.md`.
