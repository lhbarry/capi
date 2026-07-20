# Principal (Services cluster)

Hub control plane for GitOps.

## Includes

- Argo CD API server, UI (server), repo-server, redis  
- ApplicationSet controller (optional, enable when needed)  
- **argocd-agent Principal** (hub side for Workload agents)  

## Does not include

- Workload-local apply (that is the **Agent** on Workload)  
- Full ApplicationController tuning — see sibling [../application-controller](../application-controller/) values overlay  

## Placement

- Namespace: `argocd` (or `argocd-principal`)  
- Nodes: Services Reserved (`capacity.scke.io/plane=services`)  

## Values

[values-principal.yaml](values-principal.yaml)
