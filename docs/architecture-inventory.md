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

### AWS Services (right rail) — catalog

| Label | Role |
|-------|------|
| EFS · CSI (RWX) | Shared FS |
| EBS · CSI (HP block) | RWO volumes |
| S3 | Object store (Velero, artifacts, CloudTrail/Config delivery) |
| **CloudWatch · CP Logs Only** | EKS control-plane log delivery target only; not day-2 ops UI |
| **CloudTrail** | API audit → S3 (`aws_security/detection.yaml`) |
| **GuardDuty** | Threat detection |
| **Config** | Configuration compliance → S3 |

Do not add further rail products without an architecture decision and SVG update.

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
| Keycloak | Services | **Reuse GitLab** (vSphere SCKE) — map in [gitops-source-reuse.md](gitops-source-reuse.md); thin AWS overlay in this repo |
| OAuth2 Proxy | Services | **Reuse GitLab** (vSphere SCKE) |
| Harbor | Services | **Reuse GitLab** (vSphere SCKE) |
| OpenBao | Services — **secrets SoR** | **Reuse GitLab** (vSphere SCKE) |
| External Secrets Operator | Services — OpenBao → K8s Secrets only | **Reuse GitLab** (vSphere SCKE) |
| CloudNativePG | Services | **Reuse GitLab** (vSphere SCKE) + EBS CSI |
| **OpenTelemetry** | **Services gateway** + **Workload agents** | **Reuse GitLab** (SCKE:Observability) + `aws_eks/services/lgtm/collectors/` AWS deltas (CW CP) |
| **Grafana LGTM** (Loki · Tempo · Mimir) | Services | **Reuse GitLab** (SCKE:Observability) + `aws_eks/services/lgtm/` alerts overlays |

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

## GitOps source model (locked)

**Installable desired state for Services peers is primarily in GitLab**, proven on **vSphere-hosted SCKE** (including **SCKE:Observability**). Chart version pins and proven values are reused on AWS EKS via Argo CD.

This repo supplies **substrate + AWS overlays + topology**, not a full rewrite of every platform chart.  
Details and mapping table: **[gitops-source-reuse.md](gitops-source-reuse.md)**.

## Secrets management (locked)

| Component | Role |
|-----------|------|
| **OpenBao** | System of record for secrets |
| **External Secrets Operator** | Syncs OpenBao → Kubernetes `Secret`s |

**AWS Secrets Manager is not in the architecture** for platform or app secrets. Do not cite it in WAF evidence as a secrets backend.

*(CAPA controller IAM may still reference AWS Secrets Manager ARNs for cluster bootstrap secrets — that is CAPA platform plumbing, not the Secrets capability on the Services plane.)*

---

## Explicitly **not** architecture services

| Item | How WAF / docs treat it |
|------|-------------------------|
| Fluent Bit / other shippers | Not catalogued. Telemetry agent = **OpenTelemetry only** |
| CloudWatch Alarms / Container Insights | Not baseline. Alerts = **Grafana/Mimir** |
| CloudWatch as day-2 ops UI | **Not used.** Scope = **CP Logs Only** on the rail |
| AWS Secrets Manager (app/platform secrets) | **Removed.** OpenBao + ESO only |

---

## EKS CP logs path (investigated)

1. **AWS constraint:** EKS control-plane logging delivers **only** to **CloudWatch Logs** (`/aws/eks/<cluster>/cluster`). There is no alternate first hop for managed EKS CP logs.  
2. **OTel can collect them:** OpenTelemetry Collector **contrib** includes the **`awscloudwatchlogs` receiver**, which polls CloudWatch Logs groups and feeds the collector pipeline.  
3. **Architecture path:** CAPA enables CP log types → **CloudWatch (CP Logs Only)** → **OTel gateway** (`awscloudwatchlogs` receiver) → **Loki** (LGTM).  
4. Day-2 operators query **Grafana/Loki**, not the CloudWatch console for cluster ops.

Evidence sketch: `aws_eks/services/lgtm/collectors/otel-gateway-sketch.yaml`.

---

## WAF evaluation rule (mandatory)

1. **Telemetry:** OpenTelemetry (agents Workload, gateway Services) → Grafana LGTM.  
2. **CP logs:** CloudWatch (CP Logs Only) + OTel pull → Loki.  
3. **Detection:** CloudTrail · GuardDuty · Config (AWS rail) + S3 storage.  
4. **Secrets:** OpenBao + ESO only.  
5. **Backup:** Velero + S3.  
6. Do not invent rail products or alternate secrets backends.

---

## Fidelity matrix (diagram → evidence)

| Diagram service | Evidence | Status |
|-----------------|----------|--------|
| OpenTelemetry | `aws_eks/services/lgtm/collectors/` | Aligned |
| Grafana LGTM | `aws_eks/services/lgtm/` + `alerts/` | Aligned |
| CloudWatch CP Logs Only | CAPA `logging:`; OTel `awscloudwatchlogs` | Aligned |
| CloudTrail / GuardDuty / Config | `aws_security/detection.yaml` | Aligned (now on rail) |
| OpenBao + ESO | Catalog + diagram | Aligned (no AWS SM) |
| Argo / Karpenter / Velero | respective trees | Aligned |
| EFS / EBS / S3 | side surfaces | Aligned |
