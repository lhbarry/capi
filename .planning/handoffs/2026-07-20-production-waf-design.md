# Handoff: Production design phase (high WAF)

**Date:** 2026-07-20  
**Phase shift:** Lab foundation **complete**. Work now is **production design** for a **high Well-Architected score**, built on that foundation.

---

## Framing (do not regress)

| Was (lab) | Is (now) |
|-----------|----------|
| Lab / demo criticality | **Production** criticality |
| Cost-min 1 worker / 2 AZ | **3 AZ**, bootstrap **2**, Reserved **3/5/5** + **1.5× headroom** |
| “Pure-dev / don’t apply” as goal | Intentional promotion; design is production-grade |
| Optional Services extras | Services plane **required** for WAF target |

WAF targets: **ARCHITECTURE.md §1.1** (overall **≥ 3.8**, pillar floors, no open Critical).

---

## In-repo production baseline (this phase)

- ARCHITECTURE / README reframed to production + WAF  
- `capi-eks-1`: **3 AZ**, **2** bootstrap replicas, production tags, hardens retained  
- Karpenter: Reserved **5 services + 5 workload**, headroom **1.5× t3.large**, mgmt **3 Reserved** documented  
- Budget template renamed intent (`scke-production-monthly`, higher default)

---

## Constraints still true

1. Experimental Flux on Kind can still create AWS if `resources` enabled + push — promote deliberately.  
2. Management **host** still TBD; **capacity (3 Reserved)** is not.  
3. Karpenter **controller IRSA** + subnet discovery tags not live yet.  
4. Argo CD and peer Services not manifested yet.

---

## Next slices (WAF-ordered)

1. Management host decision + 3 Reserved implementation path  
2. Karpenter production install (IRSA, discovery tags, dedicated node role)  
3. Argo CD Principal + Agent  
4. Velero + restore drill; detection (CloudTrail/Config/GuardDuty or SIEM path)  
5. IRSA per service as each lands  
6. Full `/wa-review` score → close Critical/High to §1.1  

---

## Local git (no push assumed)

Commits may be ahead of `origin/main`. Push only on intentional environment promotion.
