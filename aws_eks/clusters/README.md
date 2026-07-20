# CAPA EKS clusters — Services + Workload

**Three-cluster map:** [docs/clusters.md](../../docs/clusters.md)

| Cluster | Path | CAPA name | Role |
|---------|------|-----------|------|
| **Management** | [`management/`](../../management/) | N/A (RKE2) | Rancher, CAPI/CAPA |
| **Services** | [`services/cluster.yaml`](services/cluster.yaml) | `capi-eks-services` | Argo Principal + ApplicationController, platform |
| **Workload** | [`workload/cluster.yaml`](workload/cluster.yaml) | `capi-eks-workload` | Argo Agent, apps |

Legacy monocluster `capi-eks-1` is **removed** (split into the two CAPA definitions above).

## Safety

Keep `resources: []` in this kustomization and in `services/` / `workload/` until intentional CAPA apply. Experimental Flux still tracks `./aws_eks/clusters`.

## Parameters (parent `kustomization.yaml`)

| Literal | Purpose |
|---------|---------|
| `AWS_REGION` | Both managed control planes |
| `PUBLIC_API_CIDR` | Public API allowlist on both |

## Production baseline (each CAPA EKS)

| Control | Value |
|---------|--------|
| AZs | **3** |
| Bootstrap workers | **2** |
| CP logs | All five → CloudWatch |
| Encryption | CMK `alias/cluster-api-provider-aws-eks-secrets` |
| OIDC | On |
| Pod CIDR | Services `10.96.0.0/16` · Workload `10.97.0.0/16` |

## Karpenter

| Cluster | Install | Discovery tag |
|---------|---------|-----------------|
| Services | `aws_eks/services/karpenter/` (services pools + headroom) | `karpenter.sh/discovery: capi-eks-services` |
| Workload | Workload NodePools / headroom (see karpenter README) | `karpenter.sh/discovery: capi-eks-workload` |

## IAM

`capa-iam-common` + `capa-iam-eks` + `capa-iam-ec2` (node profile + SSM).
