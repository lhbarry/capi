# Install procedure (design)

**Not executed by Flux.** Apply when Services/Workload clusters (or planes) exist.

## 0. Prerequisites

- **Two clusters:** Services EKS and Workload EKS (Agent cannot share Principal’s cluster)  
- DNS/TLS for Argo UI (OAuth2 Proxy + Keycloak later; bootstrap admin first)  
- Git readable for Application sources  
- Karpenter / Reserved pools per plane  

## 1. Services — Principal + ApplicationController (no Agent)

Single Helm release: API, UI, repo-server, redis, **application-controller**.  
**Disable ApplicationSetController.**  
**Do not** install Workload Agent here. Install **argocd-agent Principal** (hub) only.

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Example — pin chart version from VERSIONS.md / helm search
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version 10.1.4 \
  -f aws_eks/services/argocd/principal/values-principal.yaml \
  -f aws_eks/services/argocd/application-controller/values-application-controller.yaml
```

Then install **argocd-agent Principal** into the same cluster (manifests/chart from argocd-agent v0.9.x) so Workload agents can register.

Configure:

- `configs.cm` / `configs.rbac`  
- nodeSelector / tolerations for **services** plane  
- HA: `controller.replicas` / redis HA when ready  

## 2. Workload — Agent

On the **Workload** cluster kubeconfig:

```bash
# Install agent per argocd-agent getting started (version pin VERSIONS.md)
# Point agent at Principal endpoint (Services NLB / internal DNS)
# Use autonomous / independent reconcile mode so apply continues if hub is down
```

Values sketch: [agent/values-agent.yaml](agent/values-agent.yaml).

Agent must:

- Tolerate **workload** node taints  
- Not require Principal for local apply after initial sync of Application intent  
- Report status when Principal is reachable  

## 3. First Applications

| App | Destination | Purpose |
|-----|-------------|---------|
| `services-root` | Services | App-of-apps for platform peers (later) |
| `workload-root` | Workload (via Agent) | App-of-apps for tenant apps |

## 4. Auth (follow-on)

Wire Principal UI behind **OAuth2 Proxy + Keycloak** (Services plane). Until then, bootstrap admin secret only on private network.
