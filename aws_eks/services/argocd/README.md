# Argo CD — Services Principal + ApplicationController · Workload Agent

**Production CI/CD design** for SCKE. Not Flux-wired.

| Install | Cluster | Components |
|---------|---------|------------|
| **Principal** | **Services only** | Control plane (API, UI, repo-server, redis) + agent hub Principal |
| **ApplicationController** | **Services only** | Reconciles Services **Application** CRs (**not** ApplicationSetController) |
| **Agent** | **Workload only** | Local reconcile; reports to Principal; **independent** if Principal is down |

### Constraints

1. **Principal and Agent must not co-locate** (same cluster) — unsupported by Argo CD for the foreseeable future.  
2. Principal uses **ApplicationController**, **not** ApplicationSetController (`applicationSet.enabled: false`).  
3. Services and Workload are **separate clusters** (required by #1).

Full model: [architecture.md](architecture.md) · Pins: [VERSIONS.md](VERSIONS.md)

## Layout

```text
argocd/
  architecture.md
  VERSIONS.md
  README.md
  principal/                 # Services cluster
    values-principal.yaml
    kustomization.yaml
    README.md
  application-controller/    # Services cluster (can share release with principal)
    values-application-controller.yaml
    README.md
  agent/                     # Workload cluster
    values-agent.yaml
    kustomization.yaml
    README.md
  install.md
```

## Independence requirement (Workload)

Workload Agent:

1. Reconciles Applications **on the Workload cluster** (local apply).  
2. **Reports** sync/health to the Services Principal when connected.  
3. **Continues operating** from last known desired state if the Principal is unavailable (no hard runtime dependency on hub for apply).

## Node placement

| Component | Node pool / taint |
|-----------|-------------------|
| Principal + ApplicationController | `capacity.scke.io/plane=services` (Reserved Services) |
| Agent | `capacity.scke.io/plane=workload` (Reserved Workload) |

## Install order

See [install.md](install.md).

1. Services: Principal (+ shared chart components).  
2. Services: ApplicationController (same Helm release or split as documented).  
3. Workload: Agent registered to Principal.  
4. AppProjects + root Applications for services and workload.
