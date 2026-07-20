# Well-Architected scorecard — design to date

**Date:** 2026-07-20  
**Workload:** SCKE three-cluster platform (Management + Services EKS + Workload EKS)  
**Criticality:** Production  
**Evidence basis:** In-repo architecture and IaC (design completeness; not full live deployment)

## Overall: **~3.4 / 5**

| Milestone | Overall |
|-----------|--------:|
| Lab CAPA | ~2.1 |
| Substrate hardens | ~2.6 |
| Three clusters + order | ~2.9 |
| Security package | ~3.2 |
| **Reliability package** | **~3.4** |
| Production target | **≥ 3.8** |

---

## Pillar scores

| Pillar | Score | Target | Delta |
|--------|------:|-------:|-------|
| Operational Excellence | **3.2** | ≥ 4 | — |
| **Security** | **4.1** | ≥ 4 | +1.3 (was 2.8) |
| **Reliability** | **4.1** | ≥ 4 | **+1.1** (was 3.0) |
| Performance Efficiency | **2.7** | ≥ 3.5 | — |
| Cost Optimization | **2.8** | ≥ 3.5 | — |
| Sustainability | **2.6** | ≥ 3.5 | — |

---

## Reliability ≥ 4.0 — evidence map

| Theme | Design evidence | Status |
|-------|-----------------|--------|
| **Foundations / topology** | 3 clusters; 3 AZ EKS; Management etcd quorum; Services CAPA ×5; Workload Karpenter + headroom | Designed |
| **Fault isolation** | Services vs Workload split; Agent independent of Principal; CAPA order documented | Designed |
| **Change management** | Git desired state; provision order Management → Services → Workload | Designed |
| **Backup** | Velero schedules Services + Workload; BSL to S3; volume snapshots weekly | Designed |
| **Recovery** | RTO/RPO table; [restore-drill.md](../aws_eks/services/velero/restore-drill.md); Management etcd + Rancher backup notes | Designed |
| **Monitoring / alarms** | **OpenTelemetry** agents (Workload) + gateway (Services) → **Grafana LGTM** rules (`aws_eks/services/lgtm/`) | Designed |
| **HA workload placement** | Argo PDBs; topology guidance; multi-AZ CAPA | Designed |
| **Quotas** | Service quota watchlist | Designed |

### Remaining REL (go-live, not design score blockers)

| Item | Notes |
|------|-------|
| Live Velero + first drill | Must execute quarterly log |
| LGTM stack live | Required for alert rules to fire |
| Multi-region DR | Explicitly deferred |
| Chaos engineering | Optional later |

Calibration: **4.1 design** with backup, restore procedure, HA topology, alarms, and failure-mode table in git. Formal WAFR after deploy re-verifies operating evidence.

---

## Security ≥ 4.0 — evidence (summary)

**Diagram-aligned:** private EKS API, CMK secrets, encrypted volumes, Karpenter IRSA, PSS, NetworkPolicies; observability via **OpenTelemetry → LGTM** (not CW ops).

**Account controls (not AWS rail boxes):** CloudTrail→**S3**, GuardDuty, Config under `aws_security/` — use diagram **S3** for trail storage; not added to SVG AWS column. Owner may re-scope.

---

## Score mode table

```text
## WA Score: SCKE Transformative Architecture (design)

**Overall: 3.4/5** | OPS: 3.2 | SEC: 4.1 | REL: 4.1 | PERF: 2.7 | COST: 2.8 | SUS: 2.6
```
