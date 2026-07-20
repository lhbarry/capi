# Provisioning order — three clusters

**Authoritative apply sequence.** Do not reverse or skip Management.

## Order (locked)

```text
1. Management cluster installation
      └── Ubuntu 24.04 × 3, RKE2, Rancher, Turtles / CAPI / CAPA
              │
2. Route creation of Services cluster
      └── CAPA CRs applied via Management (Turtles/CAPI/CAPA) → capi-eks-services
              │
3. Route creation of Workload cluster
      └── CAPA CRs applied via Management (Turtles/CAPI/CAPA) → capi-eks-workload
```

| Step | Cluster | How | Definition |
|------|---------|-----|------------|
| **1** | **Management** | Day-0 install (CFN EC2 + RKE2 + Rancher + **Turtles** + CAPI + CAPA) | [`management/`](../management/) |
| **2** | **Services** | CAPA on Management reconciles Services cluster YAML | [`aws_eks/clusters/services/`](../aws_eks/clusters/services/) |
| **3** | **Workload** | CAPA on Management reconciles Workload cluster YAML | [`aws_eks/clusters/workload/`](../aws_eks/clusters/workload/) |

## Why this order

1. **Management first** — Turtles/CAPI/CAPA must exist before any CAPA `Cluster` / `AWSManagedControlPlane` can reconcile.  
2. **Services second** — platform hub (Argo Principal + ApplicationController, IdP path, registry, etc.) before Workload consumers.  
3. **Workload third** — Argo **Agent** needs Principal endpoint on Services; apps land after platform exists.

## Turtles / CAPI / CAPA (Management)

| Component | Role on Management |
|-----------|-------------------|
| **Cluster API Operator / Turtles** (or equivalent) | Installs and lifecycle-manages CAPI providers |
| **CAPI** | Cluster API core + lifecycle |
| **CAPA** | AWS provider — creates EKS, VPC pattern, workers from git YAML |

CAPA applies only what is in git under `aws_eks/clusters/{services,workload}/` when those paths are enabled and applied to the Management cluster API (kubectl/Helm/GitOps from Management — **not** experimental Kind Flux as production).

## After cluster create

| When | Action |
|------|--------|
| After **Services** Ready | Install Argo Principal + ApplicationController; platform peers (no Karpenter on Services) |
| After **Workload** Ready | Install **Karpenter** (Workload only); Argo **Agent** pointing at Services Principal |

## Karpenter placement (locked)

**Karpenter installs only on the Workload cluster.**  
Services capacity is **CAPA MachineDeployment** Reserved nodes (fixed floor), not Karpenter.

## Safety

- Keep CAPA kustomize `resources: []` until step 2/3 is intentional.  
- Do not create Workload before Services if Agent must register to Principal.  
- IAM (`aws_iam/`) + KMS (`aws_eks/kms/`) before first CAPA EKS create.
