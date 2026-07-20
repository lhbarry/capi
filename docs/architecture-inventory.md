# Architecture inventory — diagram ↔ docs ↔ WAF

**Source of truth for “what exists”:** `docs/architecture.svg` + `ARCHITECTURE.md` §7 capability catalog.  
**Rule:** WAF evidence and install trees must map to these services. Do **not** invent collectors or AWS rail products. Ask the owner if a gap has no catalog replacement.

---

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
| S3 | Object store (Velero, artifacts; account trail buckets *use* S3) |

**Do not add** CloudWatch, GuardDuty, Config, Firehose, Lambda, X-Ray, etc. to this rail without an explicit architecture decision and SVG update.

### Management

| Label | Definition path |
|-------|-----------------|
| SUSE Rancher / RKE2 · 3 nodes | `management/` |
| Turtles / CAPI / CAPA | Provisions Services then Workload |

### Identity bootstrap

| Label | Path |
|-------|------|
| aws_iam/ CAPA CFN | `aws_iam/` |

### Services plane (on EKS)

| Diagram component | Placement decision | Repo path for design |
|-------------------|--------------------|----------------------|
| Argo CD Principal | Services (+ ApplicationController; **not** ApplicationSetController) | `aws_eks/services/argocd/principal/`, `application-controller/` |
| Argo CD Agent | **Not on Services** — Workload only | — |
| Karpenter | **Not on Services** — Workload only | — |
| Velero | Services + Workload | `aws_eks/services/velero/` |
| Keycloak | Services | (future install tree) |
| OAuth2 Proxy | Services | (future) |
| Harbor | Services | (future) |
| OpenBao | Services | (future) |
| External Secrets Operator | Services | (future) |
| CloudNativePG | Services | (future) |
| **OpenTelemetry** | **Services gateway** + **Workload agents** | `aws_eks/services/lgtm/collectors/` |
| **Grafana LGTM** (Loki · Tempo · Mimir) | Services | `aws_eks/services/lgtm/` |

### Workload plane

| Diagram component | Notes |
|-------------------|--------|
| Network / EKS CP / Workers | CAPA `aws_eks/clusters/workload/` |
| **Argo CD Agent** | **Workload only** (no Principal co-location) |
| **Karpenter** | **Workload only** |
| Knative | Workload runtime |
| Velero | Also Workload |
| **OpenTelemetry agents** | Daemon/agents ship OTLP → Services OTel gateway |

---

## Explicitly **not** architecture (diagram) services

| Item | Origin | How WAF / docs treat it |
|------|--------|-------------------------|
| **Fluent Bit** | **Never in your architecture.** Introduced by error in an LGTM rewrite (commit `3605f2f` era); removed | **Do not cite.** Telemetry agent = **OpenTelemetry only** |
| CloudWatch Alarms / Container Insights | REL package experiment | **Removed.** Alerts = **Grafana/Mimir** (`lgtm/alerts/`) |
| CloudWatch as day-2 ops UI | Assumed AWS default | **Not used.** Operators use **Grafana** |
| CloudWatch Logs (EKS CP delivery) | **AWS API constraint** for CAPA `logging:` | **Not** an AWS-rail product box. OTel collector **receives** those groups and exports to **Loki**. Do not promote CW to the diagram rail |
| CloudTrail / GuardDuty / Config CFN | SEC package (`aws_security/`) | **Account controls**, not Services-plane apps and **not** new AWS rail boxes. Trail storage uses diagram **S3**. Owner may scope these in/out of WAFR |

---

## WAF evaluation rule (mandatory)

When scoring any pillar:

1. **Telemetry / agents:** cite **OpenTelemetry** (agents on Workload, gateway on Services) → **Grafana LGTM**.  
2. **Backup:** cite **Velero** + diagram **S3**.  
3. **CD / compute / identity / secrets / data / registry:** only catalog names (Argo, Karpenter, Keycloak, …).  
4. **AWS rail:** only **EFS · EBS · S3**. If a need has no catalog replacement, **ask** — do not invent rail services.  
5. Never introduce Fluent Bit, Firehose, Lambda, X-Ray, or CW Alarms as architecture dependencies.

---

## Fidelity matrix (diagram service → WAF evidence)

| Diagram service | WAF / design evidence | Status |
|-----------------|----------------------|--------|
| OpenTelemetry | `aws_eks/services/lgtm/collectors/` (gateway + workload agent sketches); ARCHITECTURE §7 | Aligned |
| Grafana LGTM | `aws_eks/services/lgtm/` + `alerts/` | Aligned |
| Argo Principal / AppController / Agent | `aws_eks/services/argocd/` | Aligned |
| Karpenter (Workload only) | `aws_eks/services/karpenter/` | Aligned |
| Velero | `aws_eks/services/velero/` | Aligned |
| EFS / EBS / S3 | ARCHITECTURE side surfaces; Velero BSL → S3 | Aligned (rail only) |
| Keycloak / OAuth2 / Harbor / OpenBao / ESO / CNPG / Knative | Catalog + diagram; install trees future | Catalog-aligned (no invented substitutes) |

---

## Inconsistencies closed this pass

| Issue | Resolution |
|-------|------------|
| Fluent Bit assumed as log agent | **You never catalogued it.** Agent error. Removed; OTel only |
| OTel agents under-emphasized in WAF/REL | Agents + gateway called out in SVG, §7, collectors/, inventory |
| SVG Agent “also Services” | Fixed → **Workload only** |
| SVG OTel “Collector · OTLP” only | Fixed → **Agents + gateway · OTLP → LGTM** |
| Capacity checklist: Karpenter on Services | Fixed → CAPA 5 Services / Karpenter Workload only |
| AWS rail inventions | Rule: EFS · EBS · S3 only; ask before adding |

---

## Open owner decisions (not invented)

| Topic | Question for owner |
|-------|--------------------|
| Account detection (CloudTrail / GuardDuty / Config) | Keep as **non-diagram account controls** in SEC evidence, or drop from WAFR scope? |
| EKS CP log path | Accept **AWS-required intermediate** + OTel→Loki (current design), or disable CAPA CP logging entirely? |
| AWS SM on ESO box | Diagram already shows “OpenBao / AWS SM → K8s Secrets” — keep hybrid wording or OpenBao-only? |
