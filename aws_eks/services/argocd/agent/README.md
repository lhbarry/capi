# Agent (Workload cluster)

**argocd-agent** on the Workload cluster.

## Behavior (required)

| Requirement | Implementation intent |
|-------------|----------------------|
| Reports to Principal | Agent opens connection to Services Principal; pushes status / receives intent |
| Operates independently | Local reconciliation continues if Principal is down (autonomous / managed mode per agent docs) |
| Applies on Workload only | Agent’s local apply path; no dependency on hub kubeconfig into Workload for steady-state |

## Placement

- Namespace: `argocd-agent` (or per agent docs)  
- Nodes: Workload Reserved (`capacity.scke.io/plane=workload`)  

## Does not run on Workload

- Principal UI/API  
- Services ApplicationController  

## Values

[values-agent.yaml](values-agent.yaml) — map to argocd-agent chart/manifest fields at install (field names may track upstream; re-check agent docs for v0.9.x).
