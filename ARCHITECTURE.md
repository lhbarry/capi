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
| Workers | CAPA bootstrap nodes + **Karpenter** for Reserved Services/Workload capacity |
| Services plane | Shared platform on EKS: CI/CD, compute (Karpenter), data, registry, identity, observability (see §7) |
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

**Overall target:** **≥ 3.8 / 5** with **no open Critical** findings on the production path. Lab-era score (~2.6 design) is baseline; close gaps deliberately (this document + manifests).

---

## 2. High-level topology

```text
  ┌ On Prem ────┐                                          ┌ AWS Services ─┐
  │ AD/LDAP     │   Git · aws_eks/ · aws_iam/ · docs       │ EFS CSI (RWX) │
  │ SMTP        │                                          │ EBS CSI (HP)  │
  │ MS Teams    │   Rancher/RKE2×3    Identity CFN         │ S3            │
  │             │         │                    │           │               │
  │             │         ▼                    ▼           │               │
  │             │   Services plane (on EKS) …              │               │
  │             │   Workload plane (EKS) …   ← bottom      │               │
  └─────────────┘                                          └───────────────┘
```

Same diagram as SVG: [docs/architecture.svg](docs/architecture.svg).

### Planes and side surfaces

| Layer | Kind | Where | What lives there |
|-------|------|-------|------------------|
| **Source of truth** | Plane | Git Repo | EKS CAPA YAML, IAM templates, docs; services manifests (target) |
| **Management** | Plane | **SUSE Rancher / RKE2** (3 EC2, multi-AZ) | Rancher Manager + CAPI/CAPA; provisions downstream EKS |
| **Identity bootstrap** | Plane | AWS IAM via CloudFormation | CAPA controllers + EKS CP role + node instance profile |
| **Services** | Plane | On the EKS cluster (above Workload on diagram) | Platform services: **CI/CD** (Argo CD Principal + Agent), **Karpenter**, **Velero**, secrets, data, registry, identity, observability — see §7 |
| **Workload** | Plane | AWS EKS (bottom of diagram) | Network, managed CP, CAPA workers, **Argo CD Agent**, **Knative**, **Velero** |
| **On Prem Services** | Side surface (not a plane) | Left margin | **AD / LDAP**, **SMTP**, **MS Teams** — more TBD |
| **AWS Services** | Side surface (not a plane) | Right margin | **EFS CSI (RWX)**, **EBS CSI (HP block)**, **S3** — more TBD |

**Critical rule:** CAPA (on the **Rancher/RKE2 management cluster**) provisions **AWS** (EKS, EC2, VPC, …). **Services plane** (including Argo CD Principal) and **Workload plane** (including Argo CD Agent) both sit on **downstream EKS**. Side rails are integration surfaces, not planes.

---

## 3. Control flow (target)

```text
1. Edit YAML in git (aws_eks cluster specs, aws_iam templates, later services)
2. CAPA on management (Rancher/RKE2) reconciles CAPA CRs → EKS + VPC + workers
3. Operator (when IAM changes):
      aws cloudformation deploy --template-file aws_iam/*.yaml
4. Services plane on downstream EKS (Argo CD Principal + Agent + peers) delivers
   platform services and applications from git onto the cluster
```

| Layer | Commitment |
|-------|------------|
| Management cluster | **SUSE Rancher** on **RKE2**, 3 Reserved nodes ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| Workload / Services cluster shape | CAPA → Amazon EKS + bootstrap + Karpenter (`aws_eks/`) |
| IAM for CAPA | CloudFormation in `aws_iam/` |
| Services + app CD | Argo CD Principal + Agent **on the Services plane (EKS)** |

IAM is deployed with the AWS CLI from templates in git (YAML-first, not console-first).

---

## 4. Repository map (EKS-focused)

| Path | Owns | Applied by |
|------|------|------------|
| [`management/`](management/) | Production management plane (Rancher / RKE2 design) | Day-0 + Rancher ops (grows) |
| [`aws_eks/`](aws_eks/) | Downstream EKS CAPA + Services | CAPA on management → AWS |
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

Services plane will need **additional** identities (IRSA / Pod Identity, Harbor robot accounts, Keycloak clients, DB credentials via secrets manager, etc.) — out of CAPA IAM scope; document as those land.

---

## 6. EKS workload design (`aws_eks`)

**Intent:** CAPA **`AWSManagedControlPlane`** (EKS) + CAPA **`MachineDeployment`** workers on EC2. This is the substrate for the **Services plane**.

Canonical cluster: [`aws_eks/clusters/capi-eks-1.yaml`](aws_eks/clusters/capi-eks-1.yaml)  
(Origin: `clusterctl generate` eks flavor; evolved through lab; **now production design baseline**.)

### Object graph

```text
Cluster (capi-eks-1)
  ├── controlPlaneRef → AWSManagedControlPlane   (EKS)
  └── infrastructureRef → AWSManagedCluster

MachineDeployment (capi-eks-1-md-0)          # bootstrap / system (Karpenter, CoreDNS, …)
  ├── bootstrap → NodeadmConfigTemplate
  └── infrastructureRef → AWSMachineTemplate
        ami.eksLookupType: AmazonLinux2023
        iamInstanceProfile: nodes.cluster-api-provider-aws.sigs.k8s.io

Karpenter (Services plane)                  # Reserved 5 services + 5 workload + 1.5× headroom
  ├── EC2NodeClass default
  ├── NodePool reserved-services | reserved-workload | elastic
  └── overprovisioning pause pods
```

| Resource | Manifest |
|----------|----------|
| `Cluster` + `AWSManagedCluster` | `aws_eks/clusters/capi-eks-1.yaml` |
| `AWSManagedControlPlane` | same — region, version, VPC AZ limits, hardens |
| Bootstrap MD + `AWSMachineTemplate` + `NodeadmConfigTemplate` | same |
| Karpenter capacity | `aws_eks/services/karpenter/` |
| Worker AMI | `eksLookupType: AmazonLinux2023` (EKS 1.34+) |

### Production topology knobs (design baseline)

| Knob | Production value | Why |
|------|------------------|-----|
| `network.vpc.availabilityZoneUsageLimit` | `3` | Production HA / fault isolation (WAF REL) |
| `availabilityZoneSelection` | `Ordered` | Predictable AZ pick |
| Bootstrap worker `replicas` | `2` | HA for system pods (Karpenter, CNI, CoreDNS) until node role splits |
| Kubernetes version | `v1.34.1` | Pinned in CAPA + MD |
| Reference instance | `t3.large` (or equal family) | Unit for Reserved sizing + 1.5× headroom math |
| Services Reserved | **5 nodes** | Karpenter + overprovisioning |
| Workload Reserved | **5 nodes** | Karpenter + overprovisioning |
| Management Reserved | **3 nodes** | Separate management cluster |
| Waiting headroom | **≥ 1.5 × one worker** CPU+RAM | Preemptible overprovisioning |
| Pod CIDR | `192.168.0.0/16` | `Cluster.spec.clusterNetwork` |
| Region | kustomize param `AWS_REGION` | Per environment |
| Node / bastion SSH | empty; bastion off | SSM only (WAF SEC) |
| Public API CIDR | kustomize `PUBLIC_API_CIDR` | Tight allowlist; prefer private-only when mgmt in-VPC |
| CP logging | all five → CloudWatch | Detection / audit (WAF SEC/OPS) |
| Secrets encryption | CMK `alias/cluster-api-provider-aws-eks-secrets` | Encryption at rest (WAF SEC) |
| OIDC | `associateOIDCProvider: true` | IRSA / Pod Identity foundation |
| Cost tags | Project / Environment / CostCenter / … | Attribution (WAF COST) |

**AWS-managed:** EKS control-plane HA, control-plane patching, etcd.  
**CAPA-managed:** VPC/subnets/NAT (AZ limit), bootstrap worker lifecycle.  
**Karpenter-managed:** Reserved Services/Workload pools + elastic headroom/burst.

**Pinned in YAML:** endpoint access, logging, CMK encryption, OIDC, tags, no SSH, capacity model.  
**Open for production completeness:** dedicated Karpenter node role/IRSA, management host choice, Argo + peer Services, Velero drills, detection stack, CI policy gates, VPC endpoints.

---

## 7. Services plane

Shared **platform services** that run on the EKS workload cluster. They are not CAPA cluster objects; they are the capabilities product teams and operators consume.

**CI/CD is a Services-plane capability** (not a separate plane): Argo CD Principal and Agent live here with the other platform services.

**Status:** **production design.** **Karpenter** capacity is specified in-repo under [`aws_eks/services/karpenter/`](aws_eks/services/karpenter/). Remaining Services (Argo CD, secrets, IdP, Harbor, CNPG, obs, Velero) are **next implementation slices** toward the WAF target — not optional lab extras.

### Capacity model (Reserved + headroom)

| Domain | Reserved nodes | Owner / mechanism |
|--------|---------------:|-------------------|
| **Management** cluster | **3** | RKE2 servers under **SUSE Rancher** — labels `capacity.scke.io/reservation=reserved`, `plane=management` ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| **Services** plane | **5** | Karpenter NodePool `reserved-services` + 5× pause overprovisioning |
| **Workload** plane | **5** | Karpenter NodePool `reserved-workload` + 5× pause overprovisioning |
| **Waiting headroom** | **≥ 1.5 × one worker** CPU **and** RAM | Karpenter `elastic` NodePool + preemptible pause pod (**3 vCPU / 12 GiB** vs reference `t3.large` 2 / 8 GiB) |

Reference worker: CAPA/Karpenter **`t3.large`**. Reserved nodes carry `capacity.scke.io/reservation=reserved` and a plane label/taint (`services` / `workload` / `management`). Full write-up: [`aws_eks/services/karpenter/capacity.md`](aws_eks/services/karpenter/capacity.md).

### Capability catalog

Industry names are primary; **team names** in parentheses for local vocabulary.

| Capability (industry) | Team name | Product / stack | Role |
|-----------------------|-----------|-----------------|------|
| **Continuous delivery** (GitOps CD) | CI/CD | [Argo CD](https://argo-cd.readthedocs.io/) **Principal** + **Agent** | Deploy/reconcile services & apps from git |
| **Node autoscaling** (just-in-time compute) | Compute | [Karpenter](https://karpenter.sh/) | Provisions/right-sizes EC2 nodes for pending pods; consolidates waste |
| **Serverless / event-driven runtime** | Runtime | [Knative](https://knative.dev/) | Scale-to-zero, eventing/serving on the workload cluster |
| **Backup & restore** | Resilience | [Velero](https://velero.io/) | Cluster/namespace backup & restore (often to S3); on **Workload + Services** |
| **Database platform** (PostgreSQL on Kubernetes) | Data | [CloudNativePG](https://cloudnative-pg.io/) | Cloud-native Postgres operator: HA, backups, failover |
| **OCI container registry** (incl. pull-through cache) | Image Proxy | [Harbor](https://goharbor.io/) | Image store, vulnerability scan, proxy/cache to upstream registries |
| **AuthN/AuthZ proxy** (identity-aware reverse proxy) | Auth/Auth | [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) | Protect UIs/APIs; OIDC login; forward identity headers |
| **Identity provider (IdP)** / SSO & federation | ID Federation | [Keycloak](https://www.keycloak.org/) | Users, realms, OIDC/SAML federation, client registration |
| **Secrets management** (secrets store) | Secrets | [OpenBao](https://openbao.org/) | Central secrets engine (Vault-compatible lineage); dynamic secrets, policies |
| **Secrets synchronization** (K8s secret injection) | Secrets | [External Secrets Operator](https://external-secrets.io/) | Syncs external backends (OpenBao, AWS SM, etc.) → Kubernetes `Secret`s |
| **Telemetry collection** (instrumentation pipeline) | Obs. Infra | [OpenTelemetry](https://opentelemetry.io/) | SDKs + Collector: traces, metrics, logs → backends |
| **Observability backend** (LGTM stack) | Observability | Grafana · Loki · Tempo · Mimir | Viz + logs + traces + metrics (long-term metrics via Mimir) |

### CI/CD — Argo CD Principal, ApplicationController, Agent

Industry language: **GitOps continuous delivery**. Team name: **CI/CD**.  
**Design tree:** [`aws_eks/services/argocd/`](aws_eks/services/argocd/)

| Component | Placement | Responsibility |
|-----------|-----------|----------------|
| **Principal** | **Services cluster** | Hub control plane: UI/API, git, RBAC, agent Principal; single pane of glass |
| **ApplicationController** | **Services cluster** | Reconciles **Services-plane** Applications (local to Services) |
| **Agent** | **Workload cluster** | Local reconcile of **Workload** apps; **reports** to Principal; **operates independently** if Principal is down |

```text
  Services cluster:  Principal + ApplicationController · Karpenter · platform peers
  Workload cluster:  Agent (→ reports to Principal) · Knative · apps · Velero (also Services)
```

| Concern | Choice |
|---------|--------|
| EKS cluster lifecycle | CAPA from **Rancher/RKE2 management** ([ADR-001](docs/adr/001-management-cluster-rancher.md)) |
| Principal + ApplicationController | **Services only** |
| Agent | **Workload only** (independent operation + status report) |
| Karpenter | **Services plane** (cluster compute for EKS node pools) |
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
  Side surfaces:   On Prem · AWS (EFS/EBS/S3)
```

| Flow | Components |
|------|------------|
| Deploy Services apps | Git → Principal + ApplicationController on **Services** |
| Deploy Workload apps | Git/intent → **Agent** on Workload (local apply; reports to Principal) |
| Node capacity | **Karpenter** on Services plane: **5 Reserved** services + **5 Reserved** workload + **1.5× worker** waiting headroom; mgmt **3 Reserved** on management cluster |
| Serverless / scale-to-zero | **Knative** on Workload plane |
| Backup / restore | **Velero** on Workload + Services (snapshots / object storage, often **S3**) |
| Login to operator UIs | Keycloak + OAuth2 Proxy (incl. Argo CD UI) |
| Secrets | **OpenBao** holds secrets; **External Secrets Operator** materializes them as K8s `Secret`s (can also pull AWS SM/SSM later) |
| Image supply chain | CI → Harbor; nodes pull from Harbor |
| Stateful data | CloudNativePG-managed Postgres; **EBS CSI** (RWO block), **EFS CSI** (RWX), **S3** object |
| Directory / identity federation | **AD / LDAP** (on-prem) → Keycloak (Services) where applicable |
| Signals | OTel Collector → Mimir / Loki / Tempo → Grafana |

### Side surface catalogs (growing)

Not planes — integration / dependency lists on the diagram margins.

| Surface | Entry | Notes |
|---------|-------|--------|
| **On Prem Services** | **AD / LDAP** | Corporate directory; often federated via Keycloak |
| **On Prem Services** | **SMTP** | Corporate mail relay for alerts / app mail |
| **On Prem Services** | **MS Teams** | Chat / webhook notifications for ops and apps |
| **AWS Services** | **EFS + CSI (RWX)** | Shared filesystem for multi-attach / RWX workloads |
| **AWS Services** | **EBS + CSI (HP block)** | High-performance block volumes (typically RWO) |
| **AWS Services** | **S3** | Object storage (backups, artifacts, static assets, etc.) |

Add more rows here and on the SVG as the platform grows.

**Candidates not yet decided** (pin AWS / elect OSS / on-prem / eliminate): see **[docs/platform-candidates.md](docs/platform-candidates.md)**. Use that list in architecture reviews; promote into this section and the SVG only after disposition.

### Placement

| Decision | Choice |
|----------|--------|
| Services plane host | **On EKS**, including Argo CD Principal (+ Agent), **Karpenter**, Velero |
| Workload plane | EKS substrate **including Argo CD Agent, Knative, Velero** |
| Apply path for apps / peer services | **Argo CD** |
| On Prem / AWS Services | Vertical side surfaces — not planes; inventory grows over time |
| Isolation | Dedicated namespaces per capability (and later network policies) |
| Topology | Single EKS hosts Services + Workload planes initially; multi-cluster later if blast-radius requires it |
| Capacity | **3** mgmt Reserved + **5** services Reserved + **5** workload Reserved + **1.5×** worker headroom — production floor |

### Services plane production bar

| Capability | Production design bar |
|------------|----------------------|
| Argo CD (CI/CD) | Principal + ApplicationController on **Services**; Agent on **Workload** (independent); SSO; AppProjects |
| Karpenter | Services plane; **5+5 Reserved** + **1.5× headroom**; multi-AZ; IRSA + dedicated node role; disruption budgets |
| Knative | Workload plane; quotas, multi-tenant limits, measured eventing scope |
| Velero | Workload + Services; scheduled backups to S3, immutability, **restore runbooks + drills** |
| OpenBao | HA, auto-unseal, audit, policies, namespaces |
| External Secrets Operator | Least privilege; OpenBao (+ AWS SM if hybrid); refresh policies |
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
| App/platform capacity | Karpenter **5 Reserved services + 5 Reserved workload + 1.5× headroom** | Manifests in `services/karpenter` |
| EKS API access | Private preferred; public only with tight CIDR until mgmt in-VPC | Explicit in YAML |
| Control-plane logs | All five → CloudWatch + retention / SIEM path | YAML on; SIEM open |
| Secrets encryption | CMK (`aws_eks/kms`) | YAML + template |
| Node access | SSM only; no bastion / no standing SSH | YAML + IAM policy |
| Pod identity | IRSA or EKS Pod Identity **per service** | OIDC on; per-service open |
| Observability | OTel + LGTM production HA/retention; CP logs on | Design |
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
| **Services plane CI/CD** | Argo CD Principal + Agent on EKS; limit who can change Application specs in git/hub |
| **Identity (services)** | Keycloak is the cluster IdP; OAuth2 Proxy is the enforcement edge for UIs (including Argo CD) |
| **Secrets** | OpenBao is the system of record; External Secrets is the only path that should mint long-lived K8s Secrets from it |
| **Data / registry** | CNPG and Harbor hold sensitive state — network policy + secrets discipline |
| **Telemetry** | OTel path should not become an unauthenticated write API from the internet |
| **Human → AWS** | IAM CFN deploys and break-glass; secrets only under `local/` (gitignored) |

---

## 10. Design principles

1. **Production WAF first** — design and score against high maturity (§1.1); lab work is foundation, not the goal.  
2. **EKS is the product path** — CAPA → EKS; `aws_ec2` mirrors later.  
3. **Services plane is first-class** — including CI/CD and Karpenter.  
4. **Reserved capacity is intentional** — 3 / 5 / 5 + 1.5× headroom is the production floor, not waste to eliminate casually.  
5. **Management is SUSE Rancher / RKE2** — 3 Reserved nodes; Kind path is not the product.  
6. **YAML first** — AWS and platform changes come from git.  
7. **IAM is central for CAPA** — `aws_iam/` only; per-service IRSA/Pod Identity is mandatory for production Services.  
8. **No secrets in git**.  
9. **Measure and gate** — CI validation, budgets, restore drills, pillar re-score after major slices.

---

## 11. Related docs

| Doc | Topic |
|-----|--------|
| [README.md](README.md) | Repo layout and rules |
| [aws_eks/README.md](aws_eks/README.md) | EKS path operations |
| [aws_iam/README.md](aws_iam/README.md) | IAM stacks and deploy order |
| [docs/architecture.svg](docs/architecture.svg) | System diagram (EKS + services) |
| [docs/platform-candidates.md](docs/platform-candidates.md) | Candidate backlog: pin AWS / elect OSS / on-prem / eliminate |

---

## 12. Evolution

**Phase complete:** lab CAPA/EKS foundation (IAM, scaffold, hardens, experimental Flux).  

**Current phase:** production design for **high WAF score**. Prefer order:

1. Lock production substrate (3 AZ, bootstrap HA, CMK, endpoint, tags) — **in progress in YAML**  
2. **Management plane** — pins + day-0 IaC in `management/` (**design done**); deploy VPC/DNS/TLS + bootstrap when ready  
3. **Karpenter** production path — NodePools + Reserved 5/5 + 1.5× headroom (**manifests present**; controller IRSA + discovery tags next)  
4. **Argo CD** — Principal + ApplicationController (Services), Agent (Workload); design in `aws_eks/services/argocd/` (**done**); install when clusters ready  
5. Peer services via Argo: secrets (OpenBao+ESO), IdP, Harbor, CNPG, Velero, OTel+LGTM  
6. IRSA / Pod Identity **per service**; tighten CAPA IAM with conditions  
7. CI gates (schema, policy, WAF guardrails); budgets; backup **restore drills**  
8. Full `/wa-review` re-score → close Critical/High until §1.1 targets met  
9. Then: reshape `aws_ec2/` as a clone of this production operating model  

Update this file, [docs/architecture.svg](docs/architecture.svg), and [docs/platform-candidates.md](docs/platform-candidates.md) when topology or dispositions change.
