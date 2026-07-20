# Architecture inventory — diagram ↔ docs ↔ WAF

**Source of truth for “what exists”:** `docs/architecture.svg` + `ARCHITECTURE.md` §7 capability catalog.  
**Rule:** WAF evidence and install trees must map to these services. Do **not** invent collectors or AWS rail products. Ask the owner if a gap has no catalog replacement.

## Diagram inventory (committed)

### On Prem (left rail)

| Label | Catalog / notes |
|-------|-----------------|
| AD / LDAP | On-prem directory → Keycloak federation |
| SMTP | On-prem mail |
| MS Teams | On-prem notify |

### AWS Services (right rail) — **only these**

| Label | Catalog / notes |
|-------|-----------------|
| EFS · CSI (RWX) | Shared FS |
| EBS · CSI (HP block) | RWO volumes |
| S3 | Object store (Velero, artifacts, CloudTrail bucket *uses S3*) |

**Do not add** CloudWatch, GuardDuty, Config, Firehose, etc. to this rail without an architecture decision.

### Management

| Label (updated) | Definition path |
|-----------------|-----------------|
| SUSE Rancher / RKE2 · 3 nodes | `management/` |
| Turtles / CAPI / CAPA | Provisions Services then Workload |

### Identity bootstrap

| Label | Path |
|-------|------|
| aws_iam/ CAPA CFN | `aws_iam/` |

### Services plane (on EKS)

| Diagram component | Placement decision | Repo path for design |
|-------------------|--------------------|----------------------|
| Argo CD Principal | Services cluster (+ ApplicationController) | `aws_eks/services/argocd/principal/`, `application-controller/` |
| Argo CD Agent | **Workload cluster only** (no co-location) | `aws_eks/services/argocd/agent/` |
| Karpenter | **Workload cluster only** | `aws_eks/services/karpenter/` |
| Velero | Services + Workload | `aws_eks/services/velero/` |
| Keycloak | Services | (future install tree) |
| OAuth2 Proxy | Services | (future) |
| Harbor | Services | (future) |
| OpenBao | Services | (future) |
| External Secrets Operator | Services | (future) |
| CloudNativePG | Services | (future) |
| **OpenTelemetry** | Services gateway + Workload agents | `aws_eks/services/lgtm/collectors/` |
| **Grafana LGTM** (Loki · Tempo · Mimir) | Services | `aws_eks/services/lgtm/` |

### Workload plane

| Diagram component | Notes |
|-------------------|--------|
| Network / EKS CP / Workers | CAPA `aws_eks/clusters/workload/` |
| Argo CD Agent | Agent only |
| Knative | Workload runtime |
| Velero | Also Workload |

---

## Explicitly **not** architecture services (do not treat as diagram apps)

| Item | Why it appeared | How WAF should treat it |
|------|-----------------|-------------------------|
| **Fluent Bit** | Incorrectly added in LGTM rewrite | **Removed.** Use **OpenTelemetry** only |
| CloudWatch Alarms / Container Insights | REL package | **Removed.** Alerts via **Grafana/Mimir** |
| CloudWatch as ops UI | — | **Not used** day-2 |
| CloudTrail / GuardDuty / Config CFN | SEC package | **Account controls** using **S3** (on rail) for trail storage — **not** new AWS rail boxes; not Services plane apps. Revisit if you want them out of scope for WAFR |

---

## Inconsistencies resolved (this pass)

| Issue | Resolution |
|-------|------------|
| Fluent Bit in LGTM docs | Deleted; OTel collectors only |
| Karpenter “on Services” in old prose | Workload only (diagram subtitle updated) |
| Management TBD on diagram | Updated to Rancher/RKE2 + CAPA order |
| Agent “also reconciles services” | Workload only + Principal ApplicationController on Services |
| 2 AZ lab on diagram | 3 AZ production |
| Signals path | OTel → LGTM only (ARCHITECTURE §7 already correct) |

---

## WAF evaluation rule

When scoring SEC/REL/OPS observability:

1. Cite **OpenTelemetry** + **Grafana LGTM** for telemetry and alerting.  
2. Cite **Velero** + **S3** for backup.  
3. Cite **Argo / Karpenter / Keycloak / …** only as in this inventory.  
4. Do not introduce new shippers or AWS console products as architecture dependencies.
