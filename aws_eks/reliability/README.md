# Kubernetes reliability baselines

| File | Cluster | Purpose |
|------|---------|---------|
| `pdb-argocd-services.yaml` | Services | PDBs for Argo server/repo/controller |
| `topology-argocd-services.yaml` | Services | Topology spread guidance ConfigMap |

Apply PDBs **after** Argo Principal is installed on Services.
