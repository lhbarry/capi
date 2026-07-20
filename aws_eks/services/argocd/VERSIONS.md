# Argo CD — version pins

**Last verified:** 2026-07-20  

| Component | Pin | Source |
|-----------|-----|--------|
| **Argo CD** (app) | **v3.4.5** | Upstream Argo CD |
| **argo-cd Helm chart** | **7.x / 10.1.4** line as published on [argo-helm](https://argoproj.github.io/argo-helm) — use chart that ships **appVersion v3.4.5** | `helm search repo argo/argo-cd --versions` at deploy |
| **argocd-agent** | **v0.9.0** (or newer patch on 0.9) | [argoproj-labs/argocd-agent](https://github.com/argoproj-labs/argocd-agent/releases) |

Re-resolve chart version at install:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm search repo argo/argo-cd --versions | head
```

**Policy:** Pin exact chart + app + agent versions in git when first applied; bump via PR with matrix/smoke test.
