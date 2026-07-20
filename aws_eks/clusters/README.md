# CAPA EKS clusters — Services + Workload

**Three-cluster map:** [docs/clusters.md](../../docs/clusters.md)

| Cluster | Path | CAPA name | Role |
|---------|------|-----------|------|
| **Management** | [`management/`](../../management/) | N/A (RKE2) | Rancher, CAPI/CAPA |
| **Services** | [`services/cluster.yaml`](services/cluster.yaml) | `capi-eks-services` | Principal + AppController; CAPA **5 Reserved** (no Karpenter) |
| **Workload** | [`workload/cluster.yaml`](workload/cluster.yaml) | `capi-eks-workload` | Agent; **Karpenter only here** |

**Order:** Management → Services CAPA → Workload CAPA — [docs/provisioning-order.md](../../docs/provisioning-order.md)

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
| CP logs | All five on (AWS CW sink) → ship to **Loki** (LGTM) |
| Encryption | CMK `alias/cluster-api-provider-aws-eks-secrets` |
| OIDC | On |
| Pod CIDR | Services `10.96.0.0/16` · Workload `10.97.0.0/16` |

## Karpenter

**Workload cluster only** — [`../services/karpenter/`](../services/karpenter/).  
Discovery: `karpenter.sh/discovery: capi-eks-workload`.  
Services capacity = CAPA MD replicas **5**.

## IAM

`capa-iam-common` + `capa-iam-eks` + `capa-iam-ec2` (node profile + SSM).
