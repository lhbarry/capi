# Services plane (on EKS) — production design

Platform capabilities on the CAPA-provisioned EKS cluster. Lab phase complete; this tree is the **production Services plane** implementation path for a **high WAF** score.

**Delivery:** not under Flux `aws_eks/clusters` yet. Prefer Argo CD (once landed) or explicit apply. Do not confuse experimental Kind Flux jobs with the production CD design.

## Layout

| Path | Purpose | Status |
|------|---------|--------|
| [`karpenter/`](karpenter/) | Compute — Reserved 5/5 + 1.5× headroom | Manifests present |
| [`argocd/`](argocd/) | GitOps: Principal + ApplicationController (Services), Agent (Workload) | Design + values |
| [`karpenter/`](karpenter/) | **Workload only** autoscaling | Manifests |
| [`velero/`](velero/) | Backup/restore both EKS clusters + restore drill | Design + schedules |
| [`lgtm/`](lgtm/) | **Grafana · Loki · Tempo · Mimir** + alerts (not CloudWatch) | Design + alert rules |
| (next) peers | OpenBao, ESO, Harbor, Keycloak, CNPG | Design bar in ARCHITECTURE |

## Capacity (production floor)

| Domain | Reservation |
|--------|------------:|
| Management cluster | **3 Reserved** |
| Services plane | **5 Reserved** |
| Workload plane | **5 Reserved** |
| Waiting headroom | **≥ 1.5 × one worker** CPU + RAM |

See [`karpenter/capacity.md`](karpenter/capacity.md) and [ARCHITECTURE.md §1.1](../../ARCHITECTURE.md) (WAF targets).
