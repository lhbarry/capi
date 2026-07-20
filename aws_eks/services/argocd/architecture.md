# Argo CD architecture — Principal, ApplicationController, Agent

**Status:** production design  
**Team name:** CI/CD  
**Related:** [README](README.md) · [ARCHITECTURE.md §7](../../../ARCHITECTURE.md)

## Hard constraints

| Constraint | Rule |
|------------|------|
| **No Principal + Agent co-location** | Argo CD does **not** support Principal and Agent on the **same** cluster (foreseeable future). Agent is **Workload only**. Never install Agent on Services/Principal. |
| **Controller on Principal** | Principal runs **ApplicationController**, **not** ApplicationSetController. |
| **ApplicationSetController** | **Disabled** on the Principal (Services) install. Services apps use **Application** CRs. |

## Topology (locked)

| Cluster | Components | Role |
|---------|------------|------|
| **Services cluster** | **Principal** + **ApplicationController** | Hub: UI/API, git, RBAC; ApplicationController reconciles Services **Application** CRs |
| **Workload cluster** | **Agent** only (no Principal) | Local reconcile of Workload apps; **reports** to Principal; **independent** if Principal is down |

```text
                    Git (desired state)
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────────────┐   ┌──────────────────────────┐
│  SERVICES CLUSTER       │   │  WORKLOAD CLUSTER        │
│  (no Agent)             │   │  (no Principal)          │
│                         │   │                          │
│  Principal              │◄──│── Agent (reports status) │
│   · API / UI / RBAC     │   │   · local reconcile      │
│   · repo-server         │   │   · applies manifests    │
│   · redis               │   │   · continues if hub down│
│                         │   │                          │
│  ApplicationController  │   │  Knative, apps, …        │
│   · Application CRs     │   │                          │
│   · NOT ApplicationSet  │   │                          │
│  Karpenter, peers …     │   │                          │
└─────────────────────────┘   └──────────────────────────┘
```

## Independence (Workload Agent)

| Condition | Behavior |
|-----------|----------|
| Principal **up** | Agent reports health/sync; accepts intent from hub protocol |
| Principal **down** / partition | Agent **keeps reconciling** known local Applications |
| Principal recovers | Agent re-syncs status and intent with hub |

Workload reconcile is **local** — not classic hub-only push with standing spoke credentials.

## Services ApplicationController vs Workload Agent

| | ApplicationController (Services) | Agent (Workload) |
|--|----------------------------------|------------------|
| **Cluster** | Services (with Principal) | Workload **only** |
| **Type** | **ApplicationController** | Agent local path |
| **Not** | ApplicationSetController | Principal |
| **Reconciles** | Services **Application** CRs | Workload Applications |
| **Co-location** | With Principal — required | **Forbidden** with Principal |
| **Network** | In-cluster Services API | Agent dials **out** to Principal |

## Mapping to products

| Our name | Implementation |
|----------|----------------|
| **Principal** | Argo CD control plane + argocd-agent **hub** Principal on Services |
| **ApplicationController** | Argo CD `application-controller` — **enabled** |
| **ApplicationSetController** | `applicationset-controller` — **disabled** (`applicationSet.enabled: false`) |
| **Agent** | argocd-agent on Workload only |

## Cluster layout (**two clusters required**)

Principal and Agent **cannot share a cluster**, so Services and Workload **must be separate Kubernetes clusters**.

| Cluster | Argo components |
|---------|-----------------|
| **Services EKS** | Principal + ApplicationController |
| **Workload EKS** | Agent only |

Node-pool-only split on a **single** EKS API is **not** valid for this Argo topology.

## Trust boundaries

| Boundary | Control |
|----------|---------|
| Human → Principal UI | Keycloak OIDC + OAuth2 Proxy (Services) |
| Agent → Principal | mTLS / agent credentials; agent initiates |
| Git → Principal / Agent | Deploy keys; least privilege per AppProject |
| Principal → Workload API | Not required for normal agent sync |

## Out of scope here

- CI build system  
- AppProject catalog per team  
- Full redis HA / SSO production values (sketched in values files)  
