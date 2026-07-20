# Karpenter — Workload cluster only

**Locked:** Karpenter installs **only** on **Workload** EKS (`capi-eks-workload`).  
**Not** on Services. **Not** on Management.

| Cluster | Node capacity mechanism |
|---------|-------------------------|
| Management | Fixed 3 × m7i.xlarge (RKE2) |
| Services | CAPA MachineDeployment **5 Reserved** (`aws_eks/clusters/services/`) |
| Workload | CAPA bootstrap **2** + **Karpenter** (5 Reserved + 1.5× headroom) |

## Components (Workload)

| Resource | File |
|----------|------|
| EC2NodeClass | `nodeclass-workload.yaml` (`karpenter.sh/discovery: capi-eks-workload`) |
| NodePool reserved | `nodepool-reserved-workload.yaml` |
| NodePool elastic | `nodepool-elastic.yaml` |
| Overprovision | `overprovisioning/reserved-workload.yaml` + `headroom.yaml` |

## Prerequisites (Workload)

1. Workload EKS Ready (provisioned via Management CAPA — step 3).  
2. OIDC + IRSA/Pod Identity for Karpenter controller.  
3. Subnet/SG tags `karpenter.sh/discovery: capi-eks-workload`.  
4. Bootstrap nodes ≥2 for system + Karpenter pods.

## Install

See [install.md](install.md). Apply kustomize **to Workload kubeconfig only**.

```bash
kubectl --context workload apply -k aws_eks/services/karpenter/
```

## Capacity detail

[capacity.md](capacity.md)
