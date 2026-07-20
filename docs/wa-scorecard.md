# Well-Architected scorecard — design to date

**Date:** 2026-07-20  
**Workload:** SCKE three-cluster platform (Management + Services EKS + Workload EKS)  
**Criticality:** Production  
**Evidence basis:** In-repo architecture and security IaC (design completeness; not full live deployment)

## Overall: **~3.2 / 5**

| Milestone | Overall |
|-----------|--------:|
| Lab CAPA | ~2.1 |
| Substrate hardens | ~2.6 |
| Three clusters + order | ~2.9 |
| **Security package (this update)** | **~3.2** |
| Production target | **≥ 3.8** |

---

## Pillar scores

| Pillar | Score | Target | Delta |
|--------|------:|-------:|-------|
| Operational Excellence | **3.2** | ≥ 4 | — |
| **Security** | **4.1** | ≥ 4 | **+1.3** (was 2.8) |
| Reliability | **3.0** | ≥ 4 | — |
| Performance Efficiency | **2.7** | ≥ 3.5 | — |
| Cost Optimization | **2.8** | ≥ 3.5 | — |
| Sustainability | **2.6** | ≥ 3.5 | — |

---

## Security ≥ 4.0 — evidence map

| Theme | Design evidence | Status |
|-------|-----------------|--------|
| **SEC foundations / identity** | OIDC on both EKS; IRSA template for Karpenter (`aws_iam/karpenter-irsa.yaml`); node SSM not SSH; CAPA IAM in git | Designed |
| **Detection** | Multi-region CloudTrail + log validation + CWL; GuardDuty; Config recorder + foundational rules (`aws_security/detection.yaml`) | Designed |
| **Network** | **Private-only** EKS API (`public: false`); bastion off; NetworkPolicies for Argo on Services | Designed |
| **Data protection** | EKS secrets CMK; EBS root **encrypted** on CAPA nodes; S3 SSE-KMS for trails/config; TLS in transit expected | Designed |
| **Compute protection** | PSS restricted/baseline namespaces; no public node IP | Designed |
| **Incident response** | IR stub + audit sources listed (`aws_security/incident-response.md`) | Designed (light) |
| **App security** | Argo Agent pull model (no hub standing admin into Workload); AppProject least privilege (next) | Partial |

### Remaining SEC High (do not block ≥4 design score; block production go-live)

| Item | Why still open |
|------|----------------|
| Live deploy of detection + IRSA | Templates not applied in AWS yet |
| CAPA controller IAM still broad | Upstream CAPA policy shape; condition scoping later |
| SIEM export | Trail/GuardDuty → corp SIEM not wired |
| Secrets app path | OpenBao/ESO install not done |
| Image signing / admission | Harbor + policy not installed |

Calibration: **4.1** for production **design** with comprehensive control catalog in git. Live verification would re-score after deploy; incomplete deploy should not claim 4.1 in a formal WAFR until evidence is operational.

---

## Findings (Security-focused)

| Sev | Finding | Mitigation in repo |
|-----|---------|-------------------|
| High → Med | Public EKS API | `public: false` both clusters |
| High → Med | No detection | `aws_security/detection.yaml` |
| High → Med | No IRSA for Karpenter | `aws_iam/karpenter-irsa.yaml` |
| High → Med | Unencrypted node disks | `rootVolume.encrypted: true` |
| Med | No network policy | `aws_eks/security/networkpolicy-*` |
| Med | Weak PSS | `namespaces-pss.yaml` |
| Med | IR process missing | `incident-response.md` |

---

## Score mode table

```text
## WA Score: SCKE Transformative Architecture (design)

**Overall: 3.2/5** | OPS: 3.2 | SEC: 4.1 | REL: 3.0 | PERF: 2.7 | COST: 2.8 | SUS: 2.6
```
