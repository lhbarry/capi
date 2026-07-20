# Agent (Workload cluster)

**argocd-agent** on the **Workload cluster only**.

## Hard rule

**Do not install Agent on the Services/Principal cluster.** Argo CD does not support Principal co-located with Agent (foreseeable future). Services uses **ApplicationController** instead.

## Behavior (required)

| Requirement | Implementation intent |
|-------------|----------------------|
| Reports to Principal | Agent opens connection to Services Principal; status / intent |
| Operates independently | Local reconcile continues if Principal is down |
| Applies on Workload only | Local apply path; no hub kubeconfig into Workload for steady-state |

## Placement

- **Cluster:** Workload EKS (separate from Services)  
- Namespace: `argocd-agent` (or per agent docs)  
- Nodes: Workload Reserved (`capacity.scke.io/plane=workload`)  

## Does not run on Workload

- Principal UI/API  
- ApplicationController (hub)  
- ApplicationSetController

## Values

[values-agent.yaml](values-agent.yaml) — map to argocd-agent chart/manifest fields at install (field names may track upstream; re-check agent docs for v0.9.x).
