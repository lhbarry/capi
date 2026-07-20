# Argo CD architecture — Principal, ApplicationController, Agent

**Status:** production design  
**Team name:** CI/CD  
**Related:** [ADR-style decision in README](README.md) · [ARCHITECTURE.md §7](../../../ARCHITECTURE.md)

## Topology (locked by product decision)

| Cluster | Components | Role |
|---------|------------|------|
| **Services cluster** | **Principal** + **ApplicationController** | Hub: UI/API, git, RBAC, Application CRs for services; ApplicationController reconciles **Services** apps |
| **Workload cluster** | **Agent** | Spoke: local reconcile of **Workload** apps; **reports** to Principal; **operates independently** if Principal is unreachable |

```text
                    Git (desired state)
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────────────┐   ┌──────────────────────────┐
│  SERVICES CLUSTER       │   │  WORKLOAD CLUSTER        │
│                         │   │                          │
│  Principal              │◄──│── Agent (reports status) │
│   · API / UI / RBAC     │   │   · local Application    │
│   · repo-server         │   │     controller path      │
│   · redis / redis-ha    │   │   · applies manifests    │
│                         │   │   · continues if hub down│
│  ApplicationController  │   │                          │
│   · reconciles Services │   │  Knative, apps, …        │
│     plane Applications  │   │                          │
│  Karpenter, peers …     │   │                          │
└─────────────────────────┘   └──────────────────────────┘
```

## Independence (Workload Agent)

| Condition | Behavior |
|-----------|----------|
| Principal **up** | Agent reports health/sync status; accepts Application intent from hub protocol |
| Principal **down** / network partition | Agent **keeps reconciling** Workload Applications already known locally (autonomous mode) |
| Principal recovers | Agent re-syncs status and intent with hub |

This is **not** classic hub-only Argo CD (controller on hub pushes into spoke with long-lived credentials only). Workload reconciliation is **local** to the Workload cluster.

## Services ApplicationController vs Workload Agent

| | Services ApplicationController | Workload Agent |
|--|--------------------------------|----------------|
| **Where** | Services cluster | Workload cluster |
| **Reconciles** | Services-plane Applications (Argo, platform peers, etc.) | Workload-plane Applications (apps, Knative, …) |
| **Depends on Principal** | Co-located with Principal (same cluster control plane) | Reports to Principal; **not** hard-dependent for ongoing apply |
| **Network** | In-cluster to Services API | Agent **dials out** to Principal (pull model) |

## Mapping to products

| Our name | Implementation basis |
|----------|----------------------|
| **Principal** | Argo CD control plane (API server, UI, repo-server, redis, …) + **argocd-agent Principal** component on Services |
| **ApplicationController** | Argo CD `application-controller` (and related) on Services for **local** Services Applications |
| **Agent** | **argocd-agent** on Workload (local reconcile + hub reporting) |

See [argocd-agent docs](https://argocd-agent.readthedocs.io/) (pull-based multi-cluster; project maturing — pin versions and re-validate GA status at install).

## Cluster physical layout

| Phase | Layout |
|-------|--------|
| **Near-term** | One CAPA EKS may host both planes as **namespace/node-pool isolation** (Services Reserved nodes vs Workload Reserved nodes). Install **Principal + ApplicationController** into Services namespaces/nodeSelectors; **Agent** into Workload namespaces/nodeSelectors targeting the same or separate API. |
| **Target** | Distinct **Services EKS** and **Workload EKS** (or multi-cluster CAPA). Agent always on Workload; Principal + ApplicationController always on Services. |

Capacity labels (`capacity.scke.io/plane=services|workload`) and Karpenter Reserved pools align with this split.

## Trust boundaries

| Boundary | Control |
|----------|---------|
| Human → Principal UI | Keycloak OIDC + OAuth2 Proxy (Services) |
| Agent → Principal | mTLS / agent credentials; agent initiates connection |
| Git → Principal / Agent | Deploy keys or app credentials; least privilege per AppProject |
| Principal → Workload API | **Not required** for agent mode (agent pulls); no standing admin kubeconfig from hub into workload for normal sync |

## Out of scope here

- CI build system (feeds Harbor + git only)
- AppProject catalog for every team (define when first apps land)
- Full HA redis/SSO production values (sketched in values files)
