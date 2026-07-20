# Cluster definitions — three clusters

| # | Cluster | Role | Definition | Provisioned by |
|---|---------|------|------------|----------------|
| 1 | **Management** | Rancher + RKE2 + **Turtles/CAPI/CAPA** | [`management/`](../management/) | Day-0 bootstrap |
| 2 | **Services** | Argo Principal + ApplicationController, platform | [`aws_eks/clusters/services/`](../aws_eks/clusters/services/) | CAPA on Management |
| 3 | **Workload** | Argo Agent, apps, **Karpenter** | [`aws_eks/clusters/workload/`](../aws_eks/clusters/workload/) | CAPA on Management |

**Provisioning order:** [provisioning-order.md](provisioning-order.md)

```text
1. Management install (Turtles / CAPI / CAPA)
       │
2. CAPA → Services EKS (capi-eks-services)
       │     · Principal + ApplicationController
       │     · CAPA MD × 5 Reserved (no Karpenter)
       │
3. CAPA → Workload EKS (capi-eks-workload)
             · Agent → Principal
             · Karpenter (only here)
```

## Hard rules

1. Apply order **1 → 2 → 3** only.  
2. **Karpenter on Workload only.**  
3. Argo: Principal + ApplicationController on Services; Agent on Workload; no co-location.  
4. CAPA kustomize `resources: []` until intentional step 2/3.  

## Capacity

| Cluster | Floor |
|---------|--------|
| Management | **3 ×** m7i.xlarge (4/16/100 gp3) |
| Services | CAPA **5** Reserved nodes (t3.large MD) |
| Workload | CAPA bootstrap **2** + Karpenter **5 Reserved** + **1.5×** headroom |
