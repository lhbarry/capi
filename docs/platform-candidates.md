# Platform candidates — pin, elect OSS, or eliminate

Working list of **capabilities** we may need that are **not yet committed** on the architecture diagram. Use this file as part of design review: each row must land in one disposition, then the diagram / `ARCHITECTURE.md` / Services plane catalog get updated.

**Related:** [ARCHITECTURE.md](../ARCHITECTURE.md) · [architecture.svg](architecture.svg)

---

## Process (going forward)

For every candidate:

1. **Name the need** — capability, not a brand (e.g. “object storage,” not only “S3”).
2. **Pick a disposition** (required):

| Disposition | Meaning | Then do |
|-------------|---------|---------|
| **Pin AWS** | Use a managed AWS service as the source of truth for this capability | Add to **AWS Services** side rail + catalog in `ARCHITECTURE.md` |
| **Elect OSS** | Run (or keep) an open-source component, usually on the **Services plane** | Add to Services plane catalog + diagram |
| **On-prem** | Depends on corporate / existing on-prem systems | Add to **On Prem Services** side rail |
| **Eliminate** | Explicitly out of scope, deferred, or covered by another choice | Move to **Eliminated / deferred** with one-line rationale |
| **Hybrid** | AWS *and* OSS (or on-prem) with a clear boundary | Document both sides and the integration (e.g. CloudWatch CP → OTel → Loki) |

3. **Record the decision** in the tables below (status → decided date + choice).
4. **Propagate** — update `docs/architecture.svg`, `ARCHITECTURE.md` § side surfaces / Services catalog, and `README.md` services table if user-facing.
5. **Do not** leave long-lived “maybe” items in the decided architecture without a status.

### Status values

| Status | Meaning |
|--------|---------|
| `candidate` | On the reminder list; not on the committed diagram yet |
| `pinned-aws` | Decided: AWS Services rail |
| `elected-oss` | Decided: Services plane (or other OSS placement) |
| `on-prem` | Decided: On Prem Services rail |
| `hybrid` | Decided: multi-surface with documented split |
| `eliminated` | Explicitly not pursuing (for now or forever) |

### Already committed (do not re-litigate here)

These are **on the architecture** today. Change them via architecture review, not by re-adding as candidates.

| Surface | Committed |
|---------|-----------|
| **AWS Services** | EFS + CSI, EBS + CSI, S3, **CloudWatch (CP Logs Only)**, **CloudTrail**, **GuardDuty**, **Config** |
| **On Prem Services** | AD / LDAP, SMTP, MS Teams |
| **Workload plane** | CAPA EKS substrate, **Argo CD Agent**, **Knative**, **Velero** |
| **Services cluster** | Argo Principal + ApplicationController, **Velero**, Keycloak, OAuth2 Proxy, Harbor, OpenBao, ESO, CNPG, OTel, LGTM (**no Karpenter**) |
| **Workload cluster** | Argo **Agent**, **Karpenter**, Knative, apps, Velero |

---

## AWS-side candidates

Common next AWS (or AWS-adjacent) capabilities. Default question: **pin AWS**, **cover with Services OSS**, or **eliminate**?

| Capability (need) | Typical AWS pin | OSS / Services alternative | Status | Decision / notes |
|-------------------|-----------------|----------------------------|--------|------------------|
| DNS | Route 53 | ExternalDNS + external DNS; CoreDNS only in-cluster | `candidate` | |
| Public TLS certificates | ACM | cert-manager + public CA / Let’s Encrypt | `candidate` | |
| Encryption keys / CMKs | KMS | OpenBao transit; limited substitute for AWS data-plane keys | `hybrid` | **2026-07-20:** KMS CMK for EKS secrets (`aws_eks/kms` + CAPA `encryptionConfig`); OpenBao remains app secrets SoR |
| Managed secrets (cloud) | Secrets Manager / SSM | OpenBao + External Secrets | `eliminated` | **2026-07-20:** OpenBao + ESO only; no AWS Secrets Manager in architecture |
| Cloud metrics/logs (AWS native) | **CloudWatch · CP Logs Only** (rail) | **OpenTelemetry** agents + gateway → **LGTM** | `hybrid` | CP logs: CAPA → CW → OTel `awscloudwatchlogs` → Loki. Day-2 = LGTM. No CW Alarms baseline. |
| API audit / threat / config | CloudTrail, GuardDuty, Config | — | `pinned-aws` | **2026-07-20:** on AWS Services rail; templates in `aws_security/` |
| Container registry (AWS) | ECR | Harbor (committed OSS) pull-through to ECR | `candidate` | Likely **hybrid** if Harbor proxies ECR |
| L4/L7 load balancing | NLB / ALB (+ AWS LB Controller) | MetalLB / ingress-nginx only (limited on EKS) | `candidate` | EKS almost always pins AWS LBs |
| Private service access | VPC endpoints / PrivateLink | NAT only (cost/ops tradeoff) | `candidate` | |
| Pod → AWS identity | IRSA / EKS Pod Identity | Node instance role only (weaker) | `candidate` | **Partial:** `associateOIDCProvider: true` on CAPA EKS; pin IRSA/Pod Identity per service when Services land |
| Image scanning (AWS) | ECR scanning / Inspector | Harbor scanning (already in Services) | `candidate` | |
| WAF / edge protection | WAF, CloudFront | In-cluster only (weaker for public edge) | `candidate` | |
| Backup for AWS resources | AWS Backup | Velero (elected OSS; often **hybrid** with S3) | `hybrid` | Velero on Workload+Services; S3 already pinned |
| Queue / bus | SQS, SNS, EventBridge | NATS, Kafka on Services plane | `candidate` | |
| Cache | ElastiCache | Redis/Valkey operator on Services | `candidate` | |

Add rows as new needs appear. Prefer **capability** wording in the first column.

---

## On-prem candidates

Corporate / data-center dependencies. Default question: **on-prem surface**, **replace with IdP/OSS in Services**, or **eliminate**?

| Capability (need) | Typical on-prem | Services / cloud alternative | Status | Decision / notes |
|-------------------|-----------------|------------------------------|--------|------------------|
| Enterprise directory | **AD / LDAP** (committed) | Keycloak as IdP only; cloud IdP | `on-prem` | Already on diagram; federation path via Keycloak |
| SMTP / mail relay | **SMTP** (committed) | SES; in-cluster MTA not recommended | `on-prem` | Corporate relay for alerts / app mail |
| Chat / ops notify | **MS Teams** (committed) | Slack, PagerDuty, SES-only | `on-prem` | Webhooks / bots for platform and app alerts |
| Internal DNS | Corporate DNS / BIND | Route 53 private + hybrid DNS | `candidate` | |
| Enterprise PKI / CA | Internal CA, smartcard PKI | ACM private CA; cert-manager + internal CA | `candidate` | |
| SIEM / log ship | Splunk, QRadar, syslog | OTel → LGTM; export to corporate SIEM | `candidate` | Often **hybrid** |
| File / NFS shares | On-prem NAS | EFS; S3 | `candidate` | |
| Ticketing / ITSM | ServiceNow, Jira | Out of platform scope? | `candidate` | May **eliminate** from platform |
| Source / packages (corp) | Artifactory, Nexus on-prem | Harbor; cloud artifact stores | `candidate` | |
| Network path to corp | Direct Connect, VPN, SD-WAN | Public only (usually insufficient) | `candidate` | Architecture dependency, not a “service box” only |
| Vulnerability / compliance feeds | Corp scanners | Harbor + cloud scanners | `candidate` | |

---

## Services-plane OSS candidates (not yet elected)

Items that might join the Services plane later (or stay eliminated). Not side-rail AWS/on-prem, but same decision process.

| Capability (need) | Candidate OSS | Overlaps with | Status | Decision / notes |
|-------------------|---------------|---------------|--------|------------------|
| Policy / admission | Kyverno or OPA Gatekeeper | — | `candidate` | |
| Backup / DR for cluster | **Velero** (committed) | AWS Backup | `elected-oss` | On Workload + Services planes |
| Service mesh | Linkerd or Istio | NLB/ALB only | `candidate` | |
| Progressive delivery | Argo Rollouts / Flagger | Argo CD only | `candidate` | |
| Serverless / scale-to-zero | **Knative** (committed, Workload) | Lambda; KEDA-only | `elected-oss` | On Workload plane |
| Certificate lifecycle in-cluster | cert-manager | ACM | `candidate` | |
| Secrets CSI (pod mount) | Secrets Store CSI Driver | External Secrets | `candidate` | May eliminate if ESO-only |
| GitOps for mgmt cluster | Flux / Argo on mgmt | Rancher + optional GitOps | `candidate` | Management host = Rancher/RKE2 (ADR-001); GitOps tool on mgmt still open |
| Cost visibility | OpenCost / Kubecost | AWS Cost Explorer | `candidate` | |

---

## Eliminated / deferred

Move candidates here with a date and reason. Reopen only with a new need statement.

| Capability | Former status | Date | Rationale |
|------------|---------------|------|-----------|
| AWS Secrets Manager / SSM as app secrets | candidate | 2026-07-20 | OpenBao + ESO cleanly cover secrets management |
| CloudWatch Alarms / Container Insights (baseline) | hybrid/experiment | 2026-07-20 | Alerts via Mimir/Grafana; CW rail scope = CP Logs Only |

---

## Decision log (optional chronology)

| Date | Capability | Disposition | Summary |
|------|------------|-------------|---------|
| 2026-07-17 | EFS CSI, EBS CSI, S3 | pinned-aws | On AWS Services rail |
| 2026-07-17 | AD / LDAP | on-prem | On On Prem Services rail |
| 2026-07-17 | SMTP, MS Teams | on-prem | On On Prem Services rail |
| 2026-07-17 | OpenBao, External Secrets | elected-oss | Services plane secrets path |
| 2026-07-17 | Knative | elected-oss | Workload plane serverless runtime |
| 2026-07-17 | Velero | elected-oss | Workload + Services; often S3 target |
| 2026-07-17 | Karpenter | elected-oss | (later: Workload-only — see 2026-07-20) |
| 2026-07-20 | Karpenter | elected-oss | **Workload cluster only**; Services = CAPA MD × 5 |
| 2026-07-20 | Provisioning order | — | Management → Services CAPA → Workload CAPA (Turtles/CAPI/CAPA) |
| 2026-07-17 | Argo CD, Keycloak, OAuth2 Proxy, Harbor, CNPG, OTel, LGTM | elected-oss | Services plane (see ARCHITECTURE) |
| 2026-07-20 | KMS CMK (EKS secrets) | hybrid | CAPA encryptionConfig + `aws_eks/kms`; OpenBao for app secrets |
| 2026-07-20 | CloudWatch (EKS CP logs) | pinned-aws (scoped) | On rail as **CP Logs Only**; OTel pulls → Loki; LGTM primary for ops |
| 2026-07-20 | CloudTrail, GuardDuty, Config | pinned-aws | On AWS Services rail; `aws_security/detection.yaml` |
| 2026-07-20 | AWS Secrets Manager (app secrets) | eliminated | OpenBao + ESO only |
| 2026-07-20 | CloudWatch Alarms / Container Insights | eliminated (baseline) | Replaced by Mimir/Grafana rules under aws_eks/services/lgtm/alerts |
| 2026-07-20 | IRSA foundation | candidate (partial) | OIDC associated on CAPA EKS; per-service roles later |
| 2026-07-20 | Management plane host | **SUSE Rancher / RKE2** | ADR-001; 3 Reserved; 4/16/100 gp3 |
| 2026-07-20 | Management OS | **Ubuntu 24.04 LTS** | Canonical SSM AMI; not SLE Micro |
| 2026-07-20 | Management pins | Rancher **2.14.3**, RKE2 **v1.34.9+rke2r1**, **m7i.xlarge** | management/VERSIONS.md + day-0 CFN |
| 2026-07-20 | Argo CD topology | Principal + **ApplicationController** on Services; Agent on Workload | No Principal+Agent co-location; **no ApplicationSetController** on Principal |
| 2026-07-20 | Cluster split | **3 clusters:** Management, Services EKS, Workload EKS | docs/clusters.md; CAPA defs under aws_eks/clusters/{services,workload} |
| 2026-07-20 | Services peer packages | **reuse GitLab** | Proven charts/values from vSphere SCKE (incl. SCKE:Observability); docs/gitops-source-reuse.md |

---

## How we use this in reviews

When changing architecture:

1. Open this file.
2. For each new dependency someone proposes, **add or update a candidate row** before drawing it on the SVG.
3. Close the review only when status is no longer bare `candidate` (or is explicitly left `candidate` with an owner/date in notes).
4. Prefer fewer pins: if Services plane already covers the need, **eliminate** the AWS/on-prem duplicate or document **hybrid** deliberately.
