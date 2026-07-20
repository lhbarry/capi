# SCKE Transformative Architecture

**Arch. adaptation from On-Prem to AWS Cloud Services Hosting.**

This document describes the architecture: **Cluster API + CAPA** provisioning of **Amazon EKS**, plus a **Services plane** of shared platform capabilities (including CI/CD) on that cluster.

**Visual overview:** [docs/architecture.svg](docs/architecture.svg)

**Audience:** operators of this lab, and interview / portfolio review of the design.

**Criticality:** lab / learning / demonstration — not a production multi-account platform. Lab vs production targets are explicit below.

> **Self-managed EC2 (`aws_ec2/`):** secondary. Intended to **mirror this EKS design** later; not the focus of this document.

> **Management cluster:** **TBD** — not fixed in this architecture. Repo may still contain experimental mgmt paths; they are not the design commitment.

---

## 1. Purpose

Prove and document **creating and managing EKS on AWS** with:

| Concern | Choice |
|---------|--------|
| Cluster lifecycle API | [Cluster API](https://cluster-api.sigs.k8s.io/) (CAPI) |
| AWS provider | [CAPA](https://cluster-api-aws.sigs.k8s.io/) |
| Control plane | **Amazon EKS** via CAPA `AWSManagedControlPlane` |
| Workers | CAPA `MachineDeployment` on **EC2** (AL2023 EKS AMI lookup) |
| Services plane | Shared platform on EKS: CI/CD, data, registry, identity, observability (see §7) |
| Desired state | Git (this repository) for CAPA YAML, IAM, and (target) services |
| Management plane | **TBD** (empty / undecided) |
| CAPA IAM | CloudFormation under `aws_iam/` only |

**Non-goals (today):** multi-account landing zone, multi-region DR, full production security baseline, customer application platform, self-managed kubeadm as the primary story, a committed management-cluster product.

---

## 2. High-level topology

```text
  ┌ On Prem ────┐                                          ┌ AWS Services ─┐
  │ AD/LDAP     │   Git · aws_eks/ · aws_iam/ · docs       │ EFS CSI (RWX) │
  │ SMTP        │                                          │ EBS CSI (HP)  │
  │ MS Teams    │   Management TBD    Identity CFN         │ S3            │
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
| **Management** | Plane | **TBD** | Empty by design — CAPI/CAPA host not decided |
| **Identity bootstrap** | Plane | AWS IAM via CloudFormation | CAPA controllers + EKS CP role + node instance profile |
| **Services** | Plane | On the EKS cluster (above Workload on diagram) | Platform services: **CI/CD** (Argo CD Principal + Agent), **Karpenter**, **Velero**, secrets, data, registry, identity, observability — see §7 |
| **Workload** | Plane | AWS EKS (bottom of diagram) | Network, managed CP, CAPA workers, **Argo CD Agent**, **Knative**, **Velero** |
| **On Prem Services** | Side surface (not a plane) | Left margin | **AD / LDAP**, **SMTP**, **MS Teams** — more TBD |
| **AWS Services** | Side surface (not a plane) | Right margin | **EFS CSI (RWX)**, **EBS CSI (HP block)**, **S3** — more TBD |

**Critical rule:** CAPA provisions **AWS** (EKS, EC2, VPC, …). **Services plane** (including Argo CD Principal) and **Workload plane** (including Argo CD Agent) both sit on EKS. Side rails are integration surfaces, not planes. Management is unspecified until decided.

---

## 3. Control flow (target)

```text
1. Edit YAML in git (aws_eks cluster specs, aws_iam templates, later services)
2. CAPA (once a management host exists) reconciles CAPA CRs → EKS + VPC + workers
3. Operator (when IAM changes):
      aws cloudformation deploy --template-file aws_iam/*.yaml
4. Services plane on EKS (Argo CD Principal + Agent + peers) delivers
   platform services and applications from git onto the cluster
```

Cluster lifecycle **tooling and management host are TBD**. What *is* fixed:

| Layer | Commitment |
|-------|------------|
| Workload cluster shape | CAPA → Amazon EKS + EC2 workers (`aws_eks/`) |
| IAM for CAPA | CloudFormation in `aws_iam/` |
| Services + app CD | Argo CD Principal + Agent **on the Services plane (EKS)** |

IAM is deployed with the AWS CLI from templates in git (YAML-first, not console-first).

---

## 4. Repository map (EKS-focused)

| Path | Owns | Applied by |
|------|------|------------|
| [`aws_eks/`](aws_eks/) | **Primary** — EKS CAPA cluster manifests | TBD management path (CAPA) |
| [`aws_iam/`](aws_iam/) | CAPA IAM CloudFormation | `aws cloudformation deploy` |
| [`aws_ec2/`](aws_ec2/) | Secondary / future mirror of this design | Not the architecture focus |
| [`clusters/capi-mgmt/`](clusters/capi-mgmt/) | **Lab / experimental** mgmt material | **Not** the architectural management plane |
| [`local/`](local/) | Notes, secrets, reference clones | Never commit |

Architecture does **not** treat `clusters/capi-mgmt` as the decided management product — leave that box empty until chosen.

---

## 5. IAM architecture (EKS)

**Decision:** CAPA IAM lives **only** under `aws_iam/` — never under `aws_eks/`.

| Stack | Template | Role for EKS path |
|-------|----------|-------------------|
| `capa-iam-common` | `common.yaml` | Controllers role, policy, instance profile (**required**) |
| `capa-iam-eks` | `eks.yaml` | EKS control-plane role + controllers-eks policy (**required**) |
| `capa-iam-ec2` | `ec2-self-managed.yaml` | Supplies **node** instance profile `nodes.cluster-api-provider-aws.sigs.k8s.io` used by current EKS worker flavor |

| Lab | Stacks |
|-----|--------|
| EKS lab (current flavor) | `common` + `eks` + `ec2` (for node profile) |

Details: [`aws_iam/README.md`](aws_iam/README.md).

Services plane will need **additional** identities (IRSA / Pod Identity, Harbor robot accounts, Keycloak clients, DB credentials via secrets manager, etc.) — out of CAPA IAM scope; document as those land.

---

## 6. EKS workload design (`aws_eks`)

**Intent:** CAPA **`AWSManagedControlPlane`** (EKS) + CAPA **`MachineDeployment`** workers on EC2. This is the substrate for the **Services plane**.

Canonical cluster: [`aws_eks/clusters/capi-eks-1.yaml`](aws_eks/clusters/capi-eks-1.yaml)  
(Generated from `clusterctl generate cluster --infrastructure aws --flavor eks`, then lab-tuned.)

### Object graph

```text
Cluster (capi-eks-1)
  ├── controlPlaneRef → AWSManagedControlPlane   (EKS)
  └── infrastructureRef → AWSManagedCluster

MachineDeployment (capi-eks-1-md-0)
  ├── bootstrap → NodeadmConfigTemplate
  └── infrastructureRef → AWSMachineTemplate
        ami.eksLookupType: AmazonLinux2023
        iamInstanceProfile: nodes.cluster-api-provider-aws.sigs.k8s.io
```

| Resource | Manifest |
|----------|----------|
| `Cluster` + `AWSManagedCluster` | `aws_eks/clusters/capi-eks-1.yaml` |
| `AWSManagedControlPlane` | same — region, version, VPC AZ limits |
| `MachineDeployment` + `AWSMachineTemplate` + `NodeadmConfigTemplate` | same |
| Worker AMI | `eksLookupType: AmazonLinux2023` (EKS 1.34+) |

### Lab topology knobs (current)

| Knob | Lab value | Why |
|------|-----------|-----|
| `network.vpc.availabilityZoneUsageLimit` | `2` | EKS needs ≥2 AZs; **two NATs** = cost floor |
| `availabilityZoneSelection` | `Ordered` | Predictable AZ pick |
| Worker `replicas` | `1` | Lab cost (not HA for apps) |
| Kubernetes version | `v1.34.1` | Pinned in CAPA + MD |
| Instance type | `t3.large` | Lab default |
| Pod CIDR | `192.168.0.0/16` | `Cluster.spec.clusterNetwork` |
| Region | kustomize param `AWS_REGION` | Per environment |
| Node / bastion SSH | empty (`sshKeyName: ""`); bastion off | Prefer SSM on node role |
| Public API CIDR | kustomize `PUBLIC_API_CIDR` | Lab allowlist (not `0.0.0.0/0`) |
| CP logging | all five → CloudWatch | Explicit in CAPA YAML |
| Secrets encryption | `alias/cluster-api-provider-aws-eks-secrets` | Deploy `aws_eks/kms` before create |
| OIDC | `associateOIDCProvider: true` | IRSA-ready; Pod Identity later |
| Cost tags | Project / Environment / CostCenter / … | CAPA `additionalTags` |

**AWS-managed:** EKS control-plane HA, control-plane patching, etcd.  
**CAPA-managed:** VPC/subnets/NAT pattern (via CAPA defaults + AZ limit), worker EC2 lifecycle, cluster create/update/delete via controllers.

**Pinned in YAML (substrate hardens):** endpoint access, control-plane logging, secrets encryption CMK alias, OIDC association, tags, no SSH.  
**Still open:** add-ons as CAPA objects, IRSA per service, management host, Services plane manifests.

---

## 7. Services plane

Shared **platform services** that run on the EKS workload cluster. They are not CAPA cluster objects; they are the capabilities product teams and operators consume.

**CI/CD is a Services-plane capability** (not a separate plane): Argo CD Principal and Agent live here with the other platform services.

**Status:** architecture target (capabilities defined here). Manifests / GitOps wiring not yet in-repo.

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

### CI/CD — Argo CD Principal and Agent

Industry language: **GitOps continuous delivery** with Principal (hub/control) + Agent (in-cluster reconciler). Team name: **CI/CD**.

| Component | Industry terms | Placement | Responsibility |
|-----------|----------------|-----------|----------------|
| **Argo CD Principal** | Control plane · hub | **Services plane** | Applications / ApplicationSets, git, UI/API, RBAC |
| **Argo CD Agent** | Cluster agent · spoke reconciler | **Workload plane** *and* **Services plane** | Applies/reconciles on EKS (workload substrate + services/apps) |

```text
  Workload plane:  Network · EKS CP · Workers · Argo Agent · Knative · Velero
  Services plane:  Argo Principal ◄──► Argo Agent · Karpenter · Velero · peers (IdP, Harbor, secrets, …)
```

| Concern | Choice |
|---------|--------|
| EKS cluster lifecycle | CAPA (management host **TBD**) |
| Principal | Services plane only |
| Agent | Workload plane **and** Services plane |
| Karpenter | **Services plane** (cluster compute autoscaling for the EKS node pool) |
| Knative | **Workload plane** (app runtime substrate) |
| Velero | **Workload plane** *and* **Services plane** (backup platform + cluster data) |
| Delivery of other services + applications | Argo CD (once present) |
| Auth to Argo UI | Keycloak OIDC + OAuth2 Proxy (peer services) |
| Image pulls | Harbor (peer service) |

**CI vs CD:** “CI/CD” here emphasizes **CD** (Argo CD). Build/test pipelines (CI) can feed images into **Harbor** and git manifests that Argo reconciles; CI tooling is not fixed in this document yet.

### How they relate

```text
  Workload plane:  Network · EKS CP · Workers · Argo Agent · Knative · Velero
  Services plane:  Git ──► Argo Principal ◄──► Argo Agent ──► apps/svc
                              │
                              └── UI ◄── OAuth2 Proxy ◄── Keycloak
                   Karpenter ──► EC2 nodes · Velero (also Workload) · OpenBao ◄── ESO
                   CI ──► Harbor · Apps ──► CNPG · OTel ──► LGTM
  Side surfaces:   On Prem (AD/LDAP · SMTP · MS Teams) · AWS (EFS CSI RWX · EBS CSI block · S3)
```

| Flow | Components |
|------|------------|
| Deploy services/apps | Git → Argo CD Principal → Agent (Workload + Services) on EKS |
| Node capacity | **Karpenter** on Services plane provisions/right-sizes EC2 for pending pods |
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
| Lab sizing | Single EKS holds workload + services; production may multi-cluster later |

### Lab vs production (services)

| Capability | Lab target | Production target |
|------------|------------|-------------------|
| Argo CD Principal + Agent (CI/CD) | Principal on Services; Agent on Workload + Services | HA Principal, agents per cluster, SSO, AppProjects |
| Karpenter | Services plane; NodePools / EC2NodeClass | Disruption budgets, multi-AZ, cost consolidation, IRSA |
| Knative | Serving on Workload (lab scale) | Production quotas, eventing scope, multi-tenant limits |
| Velero | Workload + Services; backup to S3 | Scheduled backups, immutability, restore runbooks, multi-cluster |
| OpenBao | Single-node / lab HA mode | HA, auto-unseal, audit, policies, namespaces |
| External Secrets Operator | Cluster-wide operator + ClusterSecretStore → OpenBao | Multi-store (OpenBao + AWS SM), refresh policies, least privilege |
| CloudNativePG | Single small Postgres; backup optional | Multi-AZ, PITR, encryption, quotas |
| Harbor | Single replica / lab storage | HA, signing/policies, pull-through |
| OAuth2 Proxy | Protect Grafana / Harbor / Argo / Keycloak | Consistent edge auth for internal tools |
| Keycloak | Single realm, lab IdP | HA, external DB (often CNPG), org IdP federation |
| OpenTelemetry | Small collector footprint | Sampling, multi-tenant attributes, limits |
| LGTM | Small footprints | HA backends, retention, auth via proxy + Keycloak |

---

## 8. Lab vs production targets (EKS substrate)

**Lab is intentional; production is the promotion target.**

| Dimension | Lab (this repo today) | Production target |
|-----------|----------------------|-------------------|
| Management plane | **TBD** (empty) | Chosen host + HA, backups, restricted API |
| Cluster lifecycle | CAPA → EKS (`aws_eks/`) | Same + policy gates, promotion envs |
| Services / app CD | Argo CD in **Services plane** (target) | HA Principal + agents, SSO, AppProjects |
| VPC / NAT | 2 AZs / 2 NATs | 3 AZs; consider VPC endpoints to cut NAT |
| Workers | 1 × `t3.large` | ≥2–3 multi-AZ (services plane needs headroom) |
| EKS API access | Private + public with `PUBLIC_API_CIDR` allowlist | Private-only when mgmt is in-VPC / VPN |
| Control-plane logs | All five explicit → CloudWatch | Same + retention / SIEM |
| Secrets encryption | CMK alias in YAML (`aws_eks/kms`) | Same; key policy reviews |
| Node access | No SSH key; SSM policy on node role | SSM only; no bastion |
| Pod identity | OIDC associated; IRSA per service not yet | IRSA or EKS Pod Identity per service |
| Observability | Services plane target (OTel + LGTM); CP logs on | Same stack, production HA/retention |
| IAM controllers | CAPA-wide policies | Tag/condition scope + access reviews |
| Cost | 2-AZ floor + CAPA tags; `aws_cost/` budget template | Deploy budget; teardown automation |
| DR | None | Multi-region strategy only if business requires |

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

1. **EKS is the product path** — architecture optimizes for CAPA → EKS.  
2. **Services plane is first-class** — shared capabilities (incl. CI/CD) are named and owned.  
3. **Management cluster is TBD** — do not invent a dual GitOps story until that host is chosen.  
4. **YAML first** — AWS and platform changes come from git.  
5. **CI/CD is on the Services plane** — Argo CD Principal + Agent on EKS, not a separate plane.  
6. **IAM is central for CAPA** — `aws_iam/` only; pod/service identity is separate.  
7. **Cost-aware lab defaults** — 2 AZ / 2 NAT called out next to the knobs.  
8. **No secrets in git**.  
9. **Document lab vs prod** — §7 (services) and §8 (substrate).  
10. **`aws_ec2` follows later** — not dual primary architectures.

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

Prefer order:

1. Work **[platform-candidates.md](docs/platform-candidates.md)** — disposition candidates before drawing new boxes  
2. Decide **management plane** (host + how CAPA is run) — keep the box empty until then  
3. Harden EKS substrate (endpoint, logging, encryption, worker capacity for services)  
   - **Done (YAML, 2026-07-20):** endpoint allowlist, CP logging, secrets CMK alias, OIDC, tags, no SSH / SSM policy on node role  
   - **Open:** worker capacity for services, deploy CMK/budget when leaving pure-dev, private-only API when mgmt in-VPC  
4. Land **Services plane**, starting with **CI/CD** (Argo CD Principal + Agent on EKS)  
5. Land peer services via Argo (secrets, IdP, Harbor, CNPG, OTel, LGTM, …)  
6. CI validation of CAPA + services manifests; CI → Harbor image flow  
7. IRSA / Pod Identity for each service (OIDC already associated on CAPA EKS)  
8. Then: reshape `aws_ec2/` as a clone of this operating model  

Update this file, [docs/architecture.svg](docs/architecture.svg), and [docs/platform-candidates.md](docs/platform-candidates.md) when topology or dispositions change.
