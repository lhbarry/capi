# Services plane (on EKS) — production design

Platform capabilities on the CAPA-provisioned EKS cluster. Lab phase complete; this tree is the **production Services plane** path for a **high WAF** score on AWS.

## GitOps source reuse (important)

Almost every diagram Services capability already has a **GitLab project** with **chart pins + proven values** from **vSphere-hosted SCKE** (including **SCKE:Observability**).

| Do | Do not |
|----|--------|
| Reuse those GitLab sources via **Argo CD** | Re-author full charts under this tree by default |
| Add **thin AWS overlays** (IRSA, StorageClass, S3 BSL, …) | Treat “missing folder in `capi`” as “no installable state” |
| Keep chart versions aligned with proven pins | Invent alternate products |

Full model + mapping table: **[docs/gitops-source-reuse.md](../../docs/gitops-source-reuse.md)**.

**Delivery:** not under Flux `aws_eks/clusters` yet. Prefer Argo CD → GitLab (peers) + this repo (substrate/overlays).

## Layout (this repo — substrate / overlays / AWS-native)

| Path | Purpose | Status |
|------|---------|--------|
| [`argocd/`](argocd/) | GitOps hub placement: Principal + ApplicationController (Services), Agent (Workload) | Design + values |
| [`karpenter/`](karpenter/) | **Workload only** autoscaling (AWS-native) | Manifests |
| [`velero/`](velero/) | Backup schedules + **S3** BSL overlays; charts from GitLab | Overlay + schedules |
| [`lgtm/`](lgtm/) | LGTM/OTel AWS deltas (CW CP path, alerts); charts from **SCKE:Observability** GitLab | Overlay + sketches |
| Peers (Keycloak, OAuth2, Harbor, OpenBao, ESO, CNPG, …) | **GitLab proven sources** | Map + overlay (see gitops-source-reuse) |

## Capacity (production floor)

| Domain | Reservation |
|--------|------------:|
| Management cluster | **3 Reserved** |
| Services plane | **5 Reserved** |
| Workload plane | **5 Reserved** |
| Waiting headroom | **≥ 1.5 × one worker** CPU + RAM |

See [`karpenter/capacity.md`](karpenter/capacity.md) and [ARCHITECTURE.md §1.1](../../ARCHITECTURE.md) (WAF targets).
