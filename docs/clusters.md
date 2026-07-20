# Cluster definitions — three clusters

Production topology is **three** clusters. Definitions live in-repo as follows.

| # | Cluster | Role | Definition path | Provisioned by |
|---|---------|------|-----------------|----------------|
| 1 | **Management** | Rancher + RKE2 + CAPI/CAPA | [`management/`](../management/) | Day-0 CFN + RKE2 bootstrap ([management/bootstrap.md](../management/bootstrap.md)) |
| 2 | **Services** | Platform: Argo Principal + ApplicationController, Karpenter (services), peers | [`aws_eks/clusters/services/`](../aws_eks/clusters/services/) | CAPA on Management |
| 3 | **Workload** | Apps: Argo Agent, Knative, tenant apps | [`aws_eks/clusters/workload/`](../aws_eks/clusters/workload/) | CAPA on Management |

```text
┌─ Management (Ubuntu 24.04 × 3, RKE2, Rancher) ─────────────┐
│  CAPI + CAPA                                                │
└─────────────┬───────────────────────────┬───────────────────┘
              │                           │
              ▼                           ▼
┌─ Services EKS ──────────────┐  ┌─ Workload EKS ─────────────┐
│  Principal + AppController  │  │  Agent (→ Principal)       │
│  Karpenter (services)       │  │  Karpenter (workload)      │
│  Platform peers             │  │  Knative, apps             │
└─────────────────────────────┘  └────────────────────────────┘
```

## Hard rules

1. **Argo:** Principal + ApplicationController on **Services** only; Agent on **Workload** only — no co-location.  
2. **Management** is **not** CAPA EKS; it is RKE2 under Rancher.  
3. Keep Flux/kustomize `resources: []` until intentional promotion.  
4. Names: `capi-eks-services`, `capi-eks-workload`; management stack `scke-management-rke2`.

## Capacity (summary)

| Cluster | Floor |
|---------|--------|
| Management | **3 ×** `m7i.xlarge` (4/16/100 gp3) |
| Services | Bootstrap **2**; Karpenter **5 Reserved** services + headroom |
| Workload | Bootstrap **2**; Karpenter **5 Reserved** workload + headroom |
