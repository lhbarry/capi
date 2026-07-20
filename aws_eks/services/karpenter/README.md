# Karpenter — Services plane (Compute)

**Placement:** Install Karpenter **per EKS cluster** (`capi-eks-services` and `capi-eks-workload`).  
**Status:** Production capacity design in-repo. Not Flux-wired.

## What this provides

| Piece | Purpose |
|-------|---------|
| `EC2NodeClass` | AMI, subnet/SG discovery, instance profile for Karpenter nodes |
| `NodePool/reserved-services` | Up to **5 Reserved** services nodes |
| `NodePool/reserved-workload` | Up to **5 Reserved** workload nodes |
| `NodePool/elastic` | Burst + **1.5 × worker** waiting headroom |
| `overprovisioning/` | Pause pods that **hold** reserved counts + headroom |
| `capacity.md` | Full capacity model |
| `management-reserved.md` | **3 Reserved** management nodes (separate cluster) |

## Prerequisites (production apply)

1. Target EKS up (Services and/or Workload) with OIDC, CMK, CP logging.  
2. Karpenter controller (Helm) + **IRSA/Pod Identity** on **that** cluster — see `install.md`.  
3. CAPA bootstrap **≥2** system nodes.  
4. Tag subnets/SGs `karpenter.sh/discovery: capi-eks-services` or `capi-eks-workload`.  
5. Apply only the NodeClass/NodePools for that cluster (do not apply workload pools on services API and vice versa).

## Apply (intentional only — not Flux)

```bash
# After controller install:
kubectl apply -k aws_eks/services/karpenter/
```

## Validate (local, no cluster required for kustomize)

```bash
kubectl kustomize aws_eks/services/karpenter/ | head
```
