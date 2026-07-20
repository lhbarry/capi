# Principal (Services cluster)

Hub control plane for GitOps.

## Includes

- Argo CD API server, UI (server), repo-server, redis  
- **ApplicationController** (via [../application-controller](../application-controller/) values) — **required**  
- **argocd-agent Principal** (hub side for Workload agents)  

## Explicitly excluded on this cluster

| Component | Why |
|-----------|-----|
| **Agent** | Argo CD does **not** support Principal co-located with Agent (foreseeable future) |
| **ApplicationSetController** | Principal uses **ApplicationController** only; ApplicationSetController is **off** |

## Placement

- Namespace: `argocd` (or `argocd-principal`)  
- Nodes: Services Reserved (`capacity.scke.io/plane=services`)  
- **Cluster:** Services EKS only (not Workload)  

## Values

[values-principal.yaml](values-principal.yaml)
