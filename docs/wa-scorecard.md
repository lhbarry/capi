# Well-Architected scorecard — design to date

**Date:** 2026-07-20  
**Workload:** SCKE three-cluster platform (Management + Services EKS + Workload EKS)  
**Criticality:** Production  
**Evidence basis:** In-repo architecture and manifests (not full live deployment)

## Overall: **~2.9 / 5**

| | Score |
|--|------:|
| Earlier lab CAPA | ~2.1 |
| After substrate hardens | ~2.6 |
| **Now (three clusters + order + Argo/Karpenter rules)** | **~2.9** |
| Production target (§1.1) | **≥ 3.8** |

---

## Pillar scores

| Pillar | Score | Target | Status |
|--------|------:|-------:|--------|
| Operational Excellence | **3.2** | ≥ 4 | YAML-first, three-cluster provisioning order, Argo topology, Turtles/CAPA path; missing CI policy gates, live runbooks |
| Security | **2.8** | ≥ 4 | CAPA hardens (logs, CMK, OIDC, SSM, allowlist); missing IRSA, detection, SIEM, private-only API |
| Reliability | **3.0** | ≥ 4 | 3 AZ, dual EKS, mgmt HA 3, Services 5 CAPA, Workload Karpenter+headroom; missing Velero drills, live HA proof |
| Performance Efficiency | **2.7** | ≥ 3.5 | Workload Karpenter right-size path; Services fixed size; no SLO/metrics process |
| Cost Optimization | **2.8** | ≥ 3.5 | Tags, budget template, intentional floors; dual EKS + fixed Services 5 cost; budgets undeployed |
| Sustainability | **2.6** | ≥ 3.5 | Workload elasticity; Services static; process gaps |

---

## Findings summary (design)

| Sev | Count | Examples |
|-----|------:|----------|
| Critical | 0 | — (lab public-default risks addressed in YAML design) |
| High | ~8 | No live IRSA; no detection stack; Velero/restore not designed; CAPA IAM still broad; dual-EKS cost; Argo/Karpenter not installed |
| Medium | many | ApplicationSet unused; CI gates; diagram SVG stale; private API pending mgmt network |

---

## Strengths (raise score)

- Explicit **Management → Services → Workload** order with Turtles/CAPI/CAPA  
- Argo Principal / ApplicationController / Agent constraints (no co-location)  
- Karpenter scoped to Workload only (clearer ops boundary)  
- Substrate hardens in both CAPA EKS defs  
- Management pins (Ubuntu, 4/16/100, Rancher/RKE2 versions)  

## Highest-leverage next (toward 3.8)

1. Runtime: install Management + CAPA-create Services + Workload  
2. Karpenter IRSA on Workload  
3. Argo Principal + Agent live  
4. Velero + restore drill  
5. Detection (CloudTrail/Config/GuardDuty or equivalent)  
6. CI schema/policy gates  

---

## Score mode table

```text
## WA Score: SCKE Transformative Architecture (design)

**Overall: 2.9/5** | OPS: 3.2 | SEC: 2.8 | REL: 3.0 | PERF: 2.7 | COST: 2.8 | SUS: 2.6
```
