# SCKE Transformative Architecture

**Arch. adaptation from On-Prem to AWS Cloud Services Hosting.**

This document is the **production design** for **Cluster API + CAPA** → **Amazon EKS**, plus a **Services plane** of shared platform capabilities (including CI/CD) on that cluster.

**Visual overview:** [docs/architecture.svg](docs/architecture.svg)

**Audience:** platform architects and operators implementing or reviewing this production system.

**Criticality:** **production** — high [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) (WAF) posture is a design goal (see §1.1).  

**Provenance:** A CAPA/EKS **lab phase is complete** (IAM split, EKS scaffold, Flux experiment, substrate hardens). That work is the foundation. **Current phase builds on it toward a high WAF–rated production design** — not another lab.

> **Self-managed EC2 (`aws_ec2/`):** secondary. Intended to **mirror this EKS production design** later; not the focus of this document.

> **Management cluster:** **SUSE Rancher on RKE2**, **3 nodes Reserved** (all servers / etcd quorum). See [ADR-001](docs/adr/001-management-cluster-rancher.md) and [`management/`](management/). Repo `clusters/capi-mgmt/` (Kind + Flux) is historical only.

---

## 1. Purpose

Design and implement **production-grade create/manage of EKS on AWS** with:

| Concern | Choice |
|---------|--------|
| Cluster lifecycle API | [Cluster API](https://cluster-api.sigs.k8s.io/) (CAPI) |
| AWS provider | [CAPA](https://cluster-api-aws.sigs.k8s.io/) |
| Control plane | **Amazon EKS** via CAPA `AWSManagedControlPlane` |
| Workers | Services: CAPA Reserved MD; Workload: CAPA bootstrap + **Karpenter** (Workload only) |
| Services plane | Platform on **Services EKS**: CI/CD (Principal + ApplicationController), data, registry, identity, observability (see §7) |
| Desired state | Git (this repository) for CAPA YAML, IAM, and Services manifests |
| Management plane | **SUSE Rancher** on **RKE2**, **3 nodes Reserved** ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| CAPA IAM | CloudFormation under `aws_iam/` only |
| WAF goal | High maturity across all six pillars (scorecard in §1.1) |

**In scope for production design:** multi-AZ substrate, explicit security baseline, reserved capacity + headroom, Services plane, observability, backup, least-privilege identity path, cost governance.

**Deferred (not abandoned):** multi-account landing zone, multi-region active-active DR (decide only if business requires), full customer multi-tenant SaaS packaging.

### 1.1 Well-Architected production target

| Pillar | Target maturity (1–5) | Production design emphasis |
|--------|----------------------:|----------------------------|
| Operational Excellence | **≥ 4** | GitOps, policy gates, runbooks, progressive delivery (Argo), CI validation |
| Security | **≥ 4** | Private API where possible, CP logs, CMK secrets, SSM-only, IRSA/Pod Identity, detection |
| Reliability | **≥ 4** | 3 AZ, Reserved 3/5/5 capacity, 1.5× headroom, Velero + restore drills, multi-node HA |
| Performance Efficiency | **≥ 3.5** | Karpenter right-sizing, Knative where fit, measured scaling |
| Cost Optimization | **≥ 3.5** | Tags, budgets, Karpenter consolidation on elastic, VPC endpoints vs NAT tradeoff |
| Sustainability | **≥ 3.5** | Right-size, scale-to-zero where safe (Knative), avoid idle waste outside Reserved floors |

**Overall target:** **≥ 3.8 / 5** with **no open Critical** findings on the production path.

### 1.2 Well-Architected score — design to date (2026-07-20)

Score reflects **in-repo production design + evidence**, not fully deployed live platform. Criticality: production.

| Pillar | Score | Critical | High | Notes |
|--------|------:|---------:|-----:|-------|
| Operational Excellence | **3.2** | 0 | 2 | Three-cluster order, Argo/Turtles path; CI gates incomplete |
| **Security** | **4.2** | 0 | 1 | Private API, rail detection, OTel+CW-CP, OpenBao+ESO design — [wa-scorecard](docs/wa-scorecard.md) |
| **Reliability** | **4.1** | 0 | 1 | 3-cluster HA, Velero design+drill, OTel→LGTM alerts, PDBs, RTO/RPO — [reliability.md](docs/reliability.md) |
| Performance Efficiency | **2.7** | 0 | 1 | Workload Karpenter; no metrics process |
| Cost Optimization | **2.8** | 0 | 1 | Tags + budget template; undeployed |
| Sustainability | **2.6** | 0 | 1 | Workload elasticity; Services static |

**Overall (design): ~3.5 / 5** · **SEC ≥ 4.0** · **REL ≥ 4.0** (design).  

**Path to overall ≥ 3.8:** live install, CI gates, OpenBao+ESO, Velero drill, cost/sustainability process.

---

## 2. High-level topology

```text
  ┌ On Prem ────┐     Git · management/ · aws_eks/ · aws_iam/     ┌ AWS Services ──────────┐
  │ AD/LDAP     │                                                   │ EFS · EBS · S3          │
  │ SMTP        │     1. Management (Rancher/RKE2 + Turtles/CAPI/CAPA)
  │ MS Teams    │              │                                    │ CloudWatch (CP Logs Only)
  └─────────────┘              ├── 2. CAPA → Services EKS           │ CloudTrail · GuardDuty  │
                               └── 3. CAPA → Workload EKS           │ Config                  │
```

**Three clusters:** [docs/clusters.md](docs/clusters.md).  
**Apply order:** [docs/provisioning-order.md](docs/provisioning-order.md) (Management → Services → Workload).

### Clusters, planes, side surfaces

| Layer | Kind | Where | What lives there |
|-------|------|-------|------------------|
| **Source of truth** | Plane | Git | CAPA YAML, IAM, management, services manifests |
| **Management** | **Cluster #1** | RKE2 + Rancher + **Turtles/CAPI/CAPA** | Provisions Services then Workload via CAPA |
| **Identity bootstrap** | Plane | AWS IAM CFN | CAPA controllers + EKS roles + node profiles |
| **Services** | **Cluster #2** | EKS `capi-eks-services` | Principal + ApplicationController; **CAPA 5 Reserved** (no Karpenter) |
| **Workload** | **Cluster #3** | EKS `capi-eks-workload` | Agent; **Karpenter** (5 Reserved + headroom); apps |
| **On Prem / AWS Services** | Side surfaces | Margins | AD/LDAP, SMTP, Teams · EFS/EBS/S3 · CloudWatch (CP Logs Only) · CloudTrail · GuardDuty · Config |

**Critical rules:** (1) Provision **1 → 2 → 3**. (2) **Karpenter on Workload only**. (3) Argo Principal never co-locates with Agent.

---

## 3. Control flow (target)

```text
1. Install Management (Ubuntu ×3, RKE2, Rancher, Turtles / CAPI / CAPA)
2. CAPA on Management creates Services EKS (git: aws_eks/clusters/services)
3. CAPA on Management creates Workload EKS (git: aws_eks/clusters/workload)
4. Install platform: Argo Principal+AppController on Services; Karpenter+Agent on Workload
5. IAM/KMS CFN from git when needed (before CAPA EKS create)
```

Full sequence: [docs/provisioning-order.md](docs/provisioning-order.md).

| Layer | Commitment |
|-------|------------|
| Management | Rancher/RKE2 + **Turtles/CAPI/CAPA** ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| Services EKS | CAPA; **5 Reserved MD**; **no Karpenter**; Argo Principal + ApplicationController |
| Workload EKS | CAPA; bootstrap 2 + **Karpenter only here**; Argo Agent |
| IAM for CAPA | CloudFormation in `aws_iam/` |

IAM is deployed with the AWS CLI from templates in git (YAML-first, not console-first).

---

## 4. Repository map (EKS-focused)

| Path | Owns | Applied by |
|------|------|------------|
| [`management/`](management/) | **Cluster #1** Management (Rancher / RKE2) | Day-0 CFN + bootstrap |
| [`aws_eks/clusters/services/`](aws_eks/clusters/services/) | **Cluster #2** Services EKS CAPA | CAPA on management → AWS |
| [`aws_eks/clusters/workload/`](aws_eks/clusters/workload/) | **Cluster #3** Workload EKS CAPA | CAPA on management → AWS |
| [`aws_eks/services/`](aws_eks/services/) | Platform installs (Argo, Karpenter, …) | Onto Services and/or Workload |
| [`aws_iam/`](aws_iam/) | CAPA IAM CloudFormation | `aws cloudformation deploy` |
| [`aws_ec2/`](aws_ec2/) | Secondary / future mirror of this design | Not the architecture focus |
| [`clusters/capi-mgmt/`](clusters/capi-mgmt/) | **Historical** Kind + Flux lab | **Not** production management |
| [`local/`](local/) | Notes, secrets, reference clones | Never commit |

Management product is **SUSE Rancher / RKE2** ([ADR-001](docs/adr/001-management-cluster-rancher.md)). Kind path is provenance only.

---

## 5. IAM architecture (EKS)

**Decision:** CAPA IAM lives **only** under `aws_iam/` — never under `aws_eks/`.

| Stack | Template | Role for EKS path |
|-------|----------|-------------------|
| `capa-iam-common` | `common.yaml` | Controllers role, policy, instance profile (**required**) |
| `capa-iam-eks` | `eks.yaml` | EKS control-plane role + controllers-eks policy (**required**) |
| `capa-iam-ec2` | `ec2-self-managed.yaml` | Supplies **node** instance profile `nodes.cluster-api-provider-aws.sigs.k8s.io` used by current EKS worker flavor |

| Path | Stacks |
|-----|--------|
| EKS production path (current flavor) | `common` + `eks` + `ec2` (node profile + SSM) |

Details: [`aws_iam/README.md`](aws_iam/README.md).

Services plane will need **additional** identities (IRSA / Pod Identity, Harbor robot accounts, Keycloak clients, DB credentials via **OpenBao** + ESO, etc.) — out of CAPA IAM scope; document as those land.

---

## 6. EKS workload design (`aws_eks`)

**Intent:** CAPA **`AWSManagedControlPlane`** (EKS) + CAPA **`MachineDeployment`** workers on EC2. This is the substrate for the **Services plane**.

**CAPA EKS definitions (two clusters):**

| Cluster | Manifest |
|---------|----------|
| Services | [`aws_eks/clusters/services/cluster.yaml`](aws_eks/clusters/services/cluster.yaml) → `capi-eks-services` |
| Workload | [`aws_eks/clusters/workload/cluster.yaml`](aws_eks/clusters/workload/cluster.yaml) → `capi-eks-workload` |

Map: [docs/clusters.md](docs/clusters.md).

### Object graph (each CAPA EKS)

```text
Cluster (capi-eks-services | capi-eks-workload)
  ├── controlPlaneRef → AWSManagedControlPlane
  └── infrastructureRef → AWSManagedCluster

MachineDeployment (*-md-0)     # bootstrap × 2 (system)
  └── AWSMachineTemplate AL2023 + NodeadmConfigTemplate

Karpenter (per cluster)
  ├── EC2NodeClass services | workload
  ├── NodePool reserved-* + elastic
  └── overprovisioning
```

### Production topology knobs (design baseline)

| Knob | Production value | Why |
|------|------------------|-----|
| `network.vpc.availabilityZoneUsageLimit` | `3` | Production HA / fault isolation (WAF REL) |
| `availabilityZoneSelection` | `Ordered` | Predictable AZ pick |
| Bootstrap worker `replicas` | `2` | HA for system pods (Karpenter, CNI, CoreDNS) until node role splits |
| Kubernetes version | `v1.34.1` | Pinned in CAPA + MD |
| Reference instance | `t3.large` (or equal family) | Unit for Reserved sizing + 1.5× headroom math |
| Services Reserved | **5 nodes** | CAPA MD replicas: 5 (**no Karpenter**) |
| Workload Reserved | **5 nodes** + headroom | **Karpenter on Workload only** |
| Management Reserved | **3 nodes** | RKE2 / Rancher |
| Waiting headroom | **≥ 1.5 × one worker** | Workload Karpenter elastic |
| Pod CIDR | Services `10.96.0.0/16` · Workload `10.97.0.0/16` | Separate clusters |
| Region | kustomize param `AWS_REGION` | Per environment |
| Node / bastion SSH | empty; bastion off | SSM only (WAF SEC) |
| Public API CIDR | kustomize `PUBLIC_API_CIDR` | Tight allowlist; prefer private-only when mgmt in-VPC |
| CP logging | CAPA enables EKS CP logs (AWS native sink); **OpenTelemetry** ships into **Loki** | Diagram: OTel + LGTM |
| Secrets encryption | CMK `alias/cluster-api-provider-aws-eks-secrets` | Encryption at rest (WAF SEC) |
| OIDC | `associateOIDCProvider: true` | IRSA / Pod Identity foundation |
| Cost tags | Project / Environment / CostCenter / … | Attribution (WAF COST) |

**AWS-managed:** EKS control-plane HA, patching, etcd.  
**CAPA-managed:** Services + Workload EKS; Services Reserved MD; Workload bootstrap.  
**Karpenter-managed (Workload only):** reserved-workload + elastic headroom.

**Open:** Karpenter IRSA, Velero drills, detection, live Argo install, CI gates, VPC endpoints.

---

## 7. Services plane

Shared **platform services** on the **Services EKS** cluster (not CAPA CRs themselves).

**CI/CD** spans clusters: **Principal + ApplicationController** on Services; **Agent** on Workload only.

**Status:** production design. **Karpenter = Workload only** ([`aws_eks/services/karpenter/`](aws_eks/services/karpenter/)). Argo design under [`aws_eks/services/argocd/`](aws_eks/services/argocd/).

### Capacity model (Reserved + headroom)

| Domain | Reserved nodes | Owner / mechanism |
|--------|---------------:|-------------------|
| **Management** | **3** | RKE2 / Rancher ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| **Services** | **5** | CAPA MD replicas: 5 — **no Karpenter** |
| **Workload** | **5** + **1.5×** headroom | CAPA bootstrap 2 + **Karpenter** (Workload only) |

Full write-up: [`aws_eks/services/karpenter/capacity.md`](aws_eks/services/karpenter/capacity.md) · order: [docs/provisioning-order.md](docs/provisioning-order.md).

### Capability catalog

Industry names are primary; **team names** in parentheses for local vocabulary.

| Capability (industry) | Team name | Product / stack | Role |
|-----------------------|-----------|-----------------|------|
| **Continuous delivery** (GitOps CD) | CI/CD | [Argo CD](https://argo-cd.readthedocs.io/) Principal + **ApplicationController** (Services); **Agent** (Workload) | Services apps via ApplicationController; Workload via independent Agent |
| **Node autoscaling** (just-in-time compute) | Compute | [Karpenter](https://karpenter.sh/) | Provisions/right-sizes EC2 nodes for pending pods; consolidates waste |
| **Serverless / event-driven runtime** | Runtime | [Knative](https://knative.dev/) | Scale-to-zero, eventing/serving on the workload cluster |
| **Backup & restore** | Resilience | [Velero](https://velero.io/) | Cluster/namespace backup & restore (often to S3); on **Workload + Services** |
| **Database platform** (PostgreSQL on Kubernetes) | Data | [CloudNativePG](https://cloudnative-pg.io/) | Cloud-native Postgres operator: HA, backups, failover |
| **OCI container registry** (incl. pull-through cache) | Image Proxy | [Harbor](https://goharbor.io/) | Image store, vulnerability scan, proxy/cache to upstream registries |
| **AuthN/AuthZ proxy** (identity-aware reverse proxy) | Auth/Auth | [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) | Protect UIs/APIs; OIDC login; forward identity headers |
| **Identity provider (IdP)** / SSO & federation | ID Federation | [Keycloak](https://www.keycloak.org/) | Users, realms, OIDC/SAML federation, client registration |
| **Secrets management** (secrets store) | Secrets | [OpenBao](https://openbao.org/) | Central secrets engine (Vault-compatible lineage); dynamic secrets, policies |
| **Secrets synchronization** (K8s secret injection) | Secrets | [External Secrets Operator](https://external-secrets.io/) | Syncs **OpenBao** → Kubernetes `Secret`s (sole secrets path; no AWS Secrets Manager) |
| **Telemetry collection** (instrumentation pipeline) | Obs. Infra | [OpenTelemetry](https://opentelemetry.io/) | **Agents** (Workload) + **gateway** (Services): traces, metrics, logs → LGTM |
| **Observability backend** (LGTM stack) | Observability | Grafana · Loki · Tempo · Mimir | Viz + logs + traces + metrics (long-term metrics via Mimir) |

### CI/CD — Argo CD Principal, ApplicationController, Agent

Industry language: **GitOps continuous delivery**. Team name: **CI/CD**.  
**Design tree:** [`aws_eks/services/argocd/`](aws_eks/services/argocd/)

| Component | Placement | Responsibility |
|-----------|-----------|----------------|
| **Principal** | **Services cluster only** | Hub: UI/API, git, RBAC, agent hub; **never** co-located with Agent |
| **ApplicationController** | **Services cluster only** | Reconciles Services **Application** CRs (**not** ApplicationSetController) |
| **ApplicationSetController** | **Not used** on Principal | Disabled — Principal uses ApplicationController |
| **Agent** | **Workload cluster only** | Local reconcile; reports to Principal; independent if Principal is down; **not** on Services |

```text
  Services cluster:  Principal + ApplicationController · CAPA ×5 Reserved · platform peers
  Workload cluster:  Agent · Karpenter · Knative · apps
```

| Concern | Choice |
|---------|--------|
| EKS cluster lifecycle | CAPA from **Rancher/RKE2 management** ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| Principal + ApplicationController | **Services only** (no Agent on this cluster) |
| ApplicationSetController | **Off** on Principal |
| Agent | **Workload only** (cannot co-locate with Principal; independent + report) |
| Karpenter | **Workload cluster only** |
| Knative | **Workload plane** |
| Velero | Workload + Services |
| Auth to Argo UI | Keycloak OIDC + OAuth2 Proxy (Services) |
| Image pulls | Harbor (Services) |

**Independence:** Workload Agent continues applying known desired state when Principal is unreachable; re-syncs status when the hub returns. See [argocd/architecture.md](aws_eks/services/argocd/architecture.md).

**CI vs CD:** “CI/CD” emphasizes **CD** (Argo CD). CI feeds **Harbor** + git; CI tooling not fixed here.

### How they relate

```text
  Workload:  Network · EKS · Workers · Argo Agent · Knative · Velero
  Services:  Git ──► Argo Principal + ApplicationController ──► services apps
                      ▲
                      │ report / intent (agent protocol)
                      │
                 Argo Agent (Workload) ──► workload apps (local apply)
                      UI ◄── OAuth2 Proxy ◄── Keycloak
             Karpenter ──► EC2 · Velero · OpenBao ◄── ESO
             CI ──► Harbor · CNPG · OTel ──► LGTM
  Side surfaces:   On Prem · AWS (EFS/EBS/S3 · CW-CP · Trail · GD · Config)
```

| Flow | Components |
|------|------------|
| Deploy Services apps | Git → Principal + ApplicationController on **Services** |
| Deploy Workload apps | Git/intent → **Agent** on Workload (local apply; reports to Principal) |
| Node capacity | Mgmt **3**; Services CAPA **5 Reserved** (no Karpenter); Workload **Karpenter** 5 Reserved + **1.5×** headroom |
| Serverless / scale-to-zero | **Knative** on Workload plane |
| Backup / restore | **Velero** on Workload + Services (snapshots / object storage, often **S3**) |
| Login to operator UIs | Keycloak + OAuth2 Proxy (incl. Argo CD UI) |
| Secrets | **OpenBao** is system of record; **External Secrets Operator** materializes OpenBao → K8s `Secret`s only |
| Image supply chain | CI → Harbor; nodes pull from Harbor |
| Stateful data | CloudNativePG-managed Postgres; **EBS CSI** (RWO block), **EFS CSI** (RWX), **S3** object |
| Directory / identity federation | **AD / LDAP** (on-prem) → Keycloak (Services) where applicable |
| Signals | **OpenTelemetry** (only telemetry agent): Workload agents + Services gateway → **Grafana LGTM** (Loki · Tempo · Mimir) |

### Side surface catalogs (growing)

Not planes — integration / dependency lists on the diagram margins.

| Surface | Entry | Notes |
|---------|-------|--------|
| **On Prem Services** | **AD / LDAP** | Corporate directory; often federated via Keycloak |
| **On Prem Services** | **SMTP** | Corporate mail relay for alerts / app mail |
| **On Prem Services** | **MS Teams** | Chat / webhook notifications for ops and apps |
| **AWS Services** | **EFS + CSI (RWX)** | Shared filesystem for multi-attach / RWX workloads |
| **AWS Services** | **EBS + CSI (HP block)** | High-performance block volumes (typically RWO) |
| **AWS Services** | **S3** | Object storage (Velero, artifacts, CloudTrail/Config delivery) |
| **AWS Services** | **CloudWatch** · **CP Logs Only** | Mandatory EKS control-plane log sink; **not** day-2 ops UI. OTel gateway reads log groups → Loki |
| **AWS Services** | **CloudTrail** | Multi-region API audit trail → **S3** (`aws_security/detection.yaml`) |
| **AWS Services** | **GuardDuty** | Threat detection (account detector) |
| **AWS Services** | **Config** | Configuration recorder + rules → **S3** |

Add more rows here and on the SVG as the platform grows.

**Candidates not yet decided** (pin AWS / elect OSS / on-prem / eliminate): see **[docs/platform-candidates.md](docs/platform-candidates.md)**. Use that list in architecture reviews; promote into this section and the SVG only after disposition.

### Placement

| Decision | Choice |
|----------|--------|
| Services cluster | EKS Principal + ApplicationController; CAPA **5 Reserved**; **no Karpenter** |
| Workload cluster | EKS Agent; **Karpenter only here**; Knative, apps |
| Workload plane | EKS substrate **including Argo CD Agent, Knative, Velero** |
| Apply path for apps / peer services | **Argo CD** |
| On Prem / AWS Services | Vertical side surfaces — not planes; inventory grows over time |
| Isolation | Dedicated namespaces per capability (and later network policies) |
| Topology | **Three clusters:** Management + Services EKS + Workload EKS ([docs/clusters.md](docs/clusters.md)) |
| Capacity | Mgmt **3× m7i**; Services CAPA **5 Reserved**; Workload bootstrap **2** + Karpenter **5** + headroom |

### Services plane production bar

| Capability | Production design bar |
|------------|----------------------|
| Argo CD (CI/CD) | Principal + ApplicationController on **Services**; Agent on **Workload** (independent); SSO; AppProjects |
| Karpenter | **Workload only**; 5 Reserved + 1.5× headroom; IRSA; Services uses CAPA MD × 5 |
| Knative | Workload plane; quotas, multi-tenant limits, measured eventing scope |
| Velero | Workload + Services; scheduled backups to S3, immutability, **restore runbooks + drills** |
| OpenBao | HA, auto-unseal, audit, policies, namespaces |
| External Secrets Operator | Least privilege; **OpenBao only** as backend; refresh policies |
| CloudNativePG | Multi-AZ, PITR, encryption, quotas |
| Harbor | HA, signing/policies, pull-through |
| OAuth2 Proxy | Consistent edge auth for operator UIs |
| Keycloak | HA, external DB (often CNPG), org IdP federation (AD/LDAP) |
| OpenTelemetry | Sampling, tenancy attributes, limits |
| LGTM | HA backends, retention, auth via proxy + Keycloak |

---

## 8. Production substrate checklist (EKS)

**Source of truth is the production column.** Historical lab values are provenance only.

| Dimension | Production design (target in-repo) | Status |
|-----------|-----------------------------------|--------|
| Management plane | **Rancher v2.14.3** / **RKE2 v1.34.9+rke2r1** / **Ubuntu 24.04** / **3× m7i.xlarge** (4/16/100 gp3) | **Locked** ADR-001 + [management/VERSIONS.md](management/VERSIONS.md); day-0 in `management/` |
| Cluster lifecycle | CAPA → EKS + policy gates + promotion envs | CAPA YAML present; gates open |
| Services / app CD | Argo CD HA on Services plane | Design; manifests next |
| VPC / AZ | **3 AZs**; VPC endpoints vs NAT as cost/security tradeoff | YAML → 3 AZ |
| Bootstrap workers | ≥2 multi-AZ system nodes | YAML → 2 |
| App/platform capacity | Services: CAPA **5 Reserved** (no Karpenter). Workload: Karpenter **5 Reserved + 1.5× headroom** | CAPA MD + `services/karpenter` |
| EKS API access | Private preferred; public only with tight CIDR until mgmt in-VPC | Explicit in YAML |
| Control-plane logs | CAPA → **CloudWatch (CP Logs Only)** → **OTel → Loki**; SIEM optional from S3/Loki | Designed |
| Secrets encryption | CMK (`aws_eks/kms`) | YAML + template |
| Node access | SSM only; no bastion / no standing SSH | YAML + IAM policy |
| Pod identity | IRSA or EKS Pod Identity **per service** | OIDC on; per-service open |
| Observability | **OpenTelemetry** + **Grafana LGTM** (diagram); HA/retention at install | Design |
| IAM controllers | Tag/condition scope + access reviews | CAPA-wide today; tighten later |
| Cost | Tags + budgets; consolidation on elastic only | Tags + `aws_cost/` template |
| DR | Backup/restore first; multi-region only if required | Velero design |

---

## 9. Trust boundaries

| Boundary | Description |
|----------|-------------|
| **Git → CAPA desired state** | Cluster specs in `aws_eks/`; how they are applied depends on future management choice |
| **CAPA → AWS** | Controllers use CAPA IAM; create EKS, VPC, EC2, … |
| **EKS workload API** | Services plane + apps run here — not on an undecided management host |
| **Services plane CI/CD** | Argo CD Principal + ApplicationController; Agent only on Workload; limit who can change Application specs in git/hub |
| **Identity (services)** | Keycloak is the cluster IdP; OAuth2 Proxy is the enforcement edge for UIs (including Argo CD) |
| **Secrets** | OpenBao is the system of record; External Secrets is the only path that should mint long-lived K8s Secrets from it |
| **Data / registry** | CNPG and Harbor hold sensitive state — network policy + secrets discipline |
| **Telemetry** | OTel path should not become an unauthenticated write API from the internet |
| **Human → AWS** | IAM CFN deploys and break-glass; secrets only under `local/` (gitignored) |

---

## 10. Design principles

1. **Production WAF first** — design and score against high maturity (§1.1–1.2).  
2. **Three clusters** — Management → Services → Workload ([docs/provisioning-order.md](docs/provisioning-order.md)).  
3. **Turtles/CAPI/CAPA on Management** create Services then Workload EKS.  
4. **Karpenter only on Workload**; Services capacity is CAPA Reserved MD.  
5. **Argo:** Principal + ApplicationController on Services; Agent on Workload (no co-location).  
6. **YAML first** — AWS and platform changes from git.  
7. **IAM central for CAPA** — `aws_iam/`; IRSA/Pod Identity per service on EKS.  
8. **No secrets in git**.  
9. **Measure and gate** — CI, budgets, restore drills, re-score after slices.

---

## 11. Related docs

| Doc | Topic |
|-----|--------|
| [docs/clusters.md](docs/clusters.md) | Three-cluster map |
| [docs/architecture-inventory.md](docs/architecture-inventory.md) | Diagram ↔ WAF service inventory (no invented services) |
| [docs/architecture.svg](docs/architecture.svg) | System diagram |
| [docs/provisioning-order.md](docs/provisioning-order.md) | Apply order 1→2→3 |
| [docs/wa-scorecard.md](docs/wa-scorecard.md) | WAF score to date |
| [docs/reliability.md](docs/reliability.md) | RTO/RPO, failure modes, REL controls |
| [management/](management/) | Management cluster |
| [aws_eks/](aws_eks/) | Services + Workload CAPA + platform installs |
| [aws_reliability/](aws_reliability/) | Quotas; alarms **retired** → LGTM |
| [aws_eks/services/lgtm/](aws_eks/services/lgtm/) | Grafana Loki Tempo Mimir + alerts |
| [docs/platform-candidates.md](docs/platform-candidates.md) | Candidate backlog |

---

## 12. Evolution

**Phase complete:** lab CAPA/EKS foundation (IAM, scaffold, hardens, experimental Flux).  

**Current phase:** production design for **high WAF score**. Prefer order:

1. Lock production substrate — **YAML done** for both CAPA EKS  
2. **Install Management** (Turtles/CAPI/CAPA) — design done; runtime next  
3. **CAPA create Services** then **Workload** — defs done  
4. **Karpenter on Workload only** — manifests; IRSA next  
5. **Argo** install Principal+AppController / Agent — design done  
6. Peer services via Argo: secrets, IdP, Harbor, CNPG, Velero, OTel+LGTM  
7. IRSA per service; CI gates; budgets; restore drills  
8. Full `/wa-review` re-score → §1.1 targets  
9. Reshape `aws_ec2/` as clone of this model  


Update this file, [docs/architecture.svg](docs/architecture.svg), and [docs/platform-candidates.md](docs/platform-candidates.md) when topology or dispositions change.
