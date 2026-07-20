# Karpenter — Services plane (Compute)

**Placement:** Services plane on the EKS “Services Cluster” (CAPA `capi-eks-1` substrate).  
**Status:** Manifests in-repo; **not** Flux-applied (`aws_eks/clusters` only). Pure-dev safe.

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

## Prerequisites (when applying for real)

1. EKS cluster up (CAPA) with OIDC (`associateOIDCProvider: true`).  
2. Karpenter controller installed (Helm) + IRSA/Pod Identity — see `install.md`.  
3. CAPA bootstrap node(s) large enough to run Karpenter + system pods.  
4. Tag subnets/SGs for discovery (`karpenter.sh/discovery: capi-eks-1`) or edit selectors.

## Apply (intentional only — not Flux)

```bash
# After controller install:
kubectl apply -k aws_eks/services/karpenter/
```

## Validate (local, no cluster required for kustomize)

```bash
kubectl kustomize aws_eks/services/karpenter/ | head
```
