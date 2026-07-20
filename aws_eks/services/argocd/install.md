# Install procedure (design)

**Not executed by Flux.** Apply when Services/Workload clusters (or planes) exist.

## 0. Prerequisites

- Services API + Workload API (or dual node pools on one EKS)  
- DNS/TLS for Argo UI (via OAuth2 Proxy + Keycloak later; bootstrap admin first)  
- Git repo readable for Application sources  
- Karpenter Reserved services/workload pools preferred  

## 1. Services — Principal + ApplicationController

Single Helm release is typical: Argo CD chart with API, UI, repo-server, redis, **and** application-controller all on Services; agent Principal sidecar/components per argocd-agent docs.

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
