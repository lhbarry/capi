# Well-Architected scorecard — design to date

**Date:** 2026-07-20 (re-score after architecture fidelity pass)  
**Workload:** SCKE Transformative Architecture — three-cluster platform  
**Criticality:** Production  
**Evidence basis:** In-repo architecture + IaC **design completeness** (not full live deployment)  
**Catalog source of truth:** `docs/architecture.svg` · `ARCHITECTURE.md` §7 · `docs/architecture-inventory.md`

## WA Score: SCKE Transformative Architecture (design)

**Overall: 3.5/5** | OPS: 3.2 | SEC: 4.2 | REL: 4.1 | PERF: 2.7 | COST: 2.8 | SUS: 2.6

| Pillar | Score | Critical | High | Medium | Low |
|--------|------:|---------:|-----:|-------:|----:|
| Operational Excellence | **3.2** | 0 | 2 | 3 | 2 |
| Security | **4.2** | 0 | 1 | 3 | 2 |
| Reliability | **4.1** | 0 | 1 | 2 | 2 |
| Performance Efficiency | **2.7** | 0 | 1 | 2 | 1 |
| Cost Optimization | **2.8** | 0 | 1 | 2 | 1 |
| Sustainability | **2.6** | 0 | 1 | 2 | 1 |

**Target overall:** ≥ 3.8 · **SEC/REL design targets met** (≥ 4.0).

| Milestone | Overall |
|-----------|--------:|
| Lab CAPA | ~2.1 |
| Substrate hardens | ~2.6 |
| Three clusters + order | ~2.9 |
| Security package | ~3.2 |
| Reliability package | ~3.4 |
| **Architecture fidelity (OTel, AWS rail, secrets)** | **~3.5** |
| Production target | **≥ 3.8** |

---

## Architecture scope (what was scored)

```text
On Prem: AD/LDAP · SMTP · MS Teams
AWS rail: EFS · EBS · S3 · CloudWatch (CP Logs Only) · CloudTrail · GuardDuty · Config
Management: SUSE Rancher / RKE2 ×3 · Turtles/CAPI/CAPA
Services EKS: Argo Principal+AppController · Velero · Keycloak · OAuth2 · Harbor ·
              OpenBao · ESO · CNPG · OTel gateway · LGTM  (CAPA ×5, no Karpenter)
Workload EKS: Argo Agent · Karpenter · Knative · Velero · OTel agents
Secrets: OpenBao + ESO only (no AWS Secrets Manager)
Telemetry: OTel agents → gateway → LGTM; CP logs: CloudWatch → OTel → Loki
```

---

## Critical and High findings

| # | Pillar | Severity | Finding | Evidence |
|---|--------|----------|---------|----------|
| 1 | OPS | **High** | No automated CI policy gates in git (local validate only); production GitOps promotion path incomplete | `scripts/validate-eks-manifests.sh` only; no `.github/workflows`; Flux `resources: []` intentional but no promote pipeline |
| 2 | OPS | **High** | Services plane peers mostly design docs, not installable desired state — ops procedures cannot be exercised | Keycloak, Harbor, OpenBao, ESO, CNPG = “future” in inventory; Argo/Velero/LGTM = sketches |
| 3 | SEC | **High** | Platform secrets path (OpenBao + ESO) and per-service IRSA not implemented beyond Karpenter IRSA template | Inventory “future”; `aws_iam/karpenter-irsa.yaml` only; CAPA OIDC on, roles incomplete |
| 4 | REL | **High** | Backup/restore and alert pipelines are design-only — no completed Velero drill; LGTM not live so rules cannot fire | `velero/restore-drill.md` log empty; `lgtm/` sketches + alert YAML without running stack |
| 5 | PERF | **High** | No performance measurement / review process tied to OTel metrics; right-sizing not data-driven yet | Karpenter NodePools present; no SLOs, no PERF runbook, LGTM not deployed |
| 6 | COST | **High** | Cost governance undeployed (budget CFN not applied); no tag-based cost allocation process in operation | `aws_cost/production-budget.yaml` template; tags on CAPA only |
| 7 | SUS | **High** | Sustainability goals / idle-waste process not defined beyond architecture intent (Knative + consolidation) | Catalog only; no SUS metrics or review cadence |

**Critical:** 0 (design phase; pure-dev safety). Re-score after go-live may promote #3/#4 if still open in production.

---

## Strengths (do not regress)

| Area | Evidence |
|------|----------|
| Three-cluster topology + order | `docs/clusters.md`, `docs/provisioning-order.md`, Management→Services→Workload |
| Private EKS API, CP logs, CMK secrets | `aws_eks/clusters/{services,workload}/cluster.yaml` |
| Detection on AWS rail | CloudTrail / GuardDuty / Config → S3 · `aws_security/detection.yaml` |
| Observability catalog fidelity | OTel agents+gateway · LGTM · CW **CP Logs Only** · no Fluent Bit · no AWS SM for secrets |
| Capacity model | Mgmt 3 · Services CAPA 5 · Workload Karpenter 5+1.5× · `karpenter/capacity.md` |
| REL design pack | Velero schedules, RTO/RPO, failure modes, PDBs, quotas watchlist |
| Management pins | ADR-001 · Ubuntu 24.04 · Rancher 2.14.3 · RKE2 · 3× m7i.xlarge |

---

## Path to overall ≥ 3.8

| Slice | Pillars lifted | Action |
|-------|----------------|--------|
| **A. Live substrate** | OPS, SEC, REL | Deploy detection + CAPA Services/Workload; keep Flux empty until promote gate exists |
| **B. Platform CD + secrets** | OPS, SEC | Install Argo Principal/Agent; OpenBao + ESO; first IRSA set |
| **C. Observability go-live** | OPS, REL, PERF | OTel agents+gateway + LGTM; wire MS Teams; confirm CP logs in Loki |
| **D. Prove recoverability** | REL | First Velero drill; log in `restore-drill.md` |
| **E. Cost + SUS process** | COST, SUS | Deploy budget; tag review; document consolidation/Knative efficiency review |

---

## Score mode table

```text
## WA Score: SCKE Transformative Architecture (design)

**Overall: 3.5/5** | OPS: 3.2 | SEC: 4.2 | REL: 4.1 | PERF: 2.7 | COST: 2.8 | SUS: 2.6
```

Calibration: **design maturity**, not operating excellence of a running multi-env platform. Formal WAFR after deploy re-verifies live evidence.
