# Karpenter — Services plane (Compute)

**Placement:** Services plane on production EKS (CAPA `capi-eks-1` substrate).  
**Status:** Production capacity design in-repo. Apply with controller install when promoting; not auto-wired through experimental Flux `aws_eks/clusters` path.

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

1. EKS up (CAPA) with OIDC, CMK encryption, CP logging.  
2. Karpenter controller (Helm) + **IRSA/Pod Identity** — see `install.md`.  
3. CAPA bootstrap **≥2** system nodes.  
4. Tag subnets/SGs `karpenter.sh/discovery: capi-eks-1` (or edit selectors).  
5. Dedicated Karpenter node role preferred over long-term reuse of CAPA node role.

## Apply (intentional only — not Flux)

```bash
# After controller install:
kubectl apply -k aws_eks/services/karpenter/
```

## Validate (local, no cluster required for kustomize)

```bash
kubectl kustomize aws_eks/services/karpenter/ | head
```
