# Architecture — CAPA → Amazon EKS (GitOps)

This document describes the **primary architecture**: GitOps-driven **Cluster API + CAPA** provisioning of **Amazon EKS**, plus a **Services plane** of shared platform capabilities that run on that cluster.

**Visual overview:** [docs/architecture.svg](docs/architecture.svg)

**Audience:** operators of this lab, and interview / portfolio review of the design.

**Criticality:** lab / learning / demonstration — not a production multi-account platform. Lab vs production targets are explicit below.

> **Self-managed EC2 (`aws_ec2/`):** secondary. Intended to **mirror this EKS design** (same GitOps/IAM patterns) later; not the focus of this document.

---

## 1. Purpose

Prove and document **creating and managing EKS on AWS** with:

| Concern | Choice |
|---------|--------|
| Cluster lifecycle API | [Cluster API](https://cluster-api.sigs.k8s.io/) (CAPI) |
| AWS provider | [CAPA](https://cluster-api-aws.sigs.k8s.io/) |
| Control plane | **Amazon EKS** via CAPA `AWSManagedControlPlane` |
| Workers | CAPA `MachineDeployment` on **EC2** (AL2023 EKS AMI lookup) |
| Services plane | Shared data, registry, identity, and observability on EKS (see §7) |
| Desired state | Git (this repository) |
| Management plane | Kind cluster (`capi-mgmt`) + Flux |
| CAPA IAM | CloudFormation under `aws_iam/` only |

**Non-goals (today):** multi-account landing zone, multi-region DR, full production security baseline, customer application platform, self-managed kubeadm as the primary story.

---

## 2. High-level topology

```text
                 ┌──────────────────────────────────┐
                 │         This Git repo            │
                 │  clusters/capi-mgmt · aws_eks/   │
                 │           aws_iam/               │
                 └───────────────┬──────────────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           │ push / Flux         │                     │ CFN deploy
           ▼                     │                     ▼
  ┌─────────────────┐            │            ┌─────────────────┐
  │ Kind: capi-mgmt │            │            │ CloudFormation  │
  │ Flux + CAPI/CAPA│            │            │ common + eks    │
  │ job: aws-eks-…  │            │            │ (+ nodes prof.) │
  └────────┬────────┘            │            └────────┬────────┘
           │ CAPA → AWS APIs     │                     │ IAM
           ▼                     │                     ▼
  ┌────────────────────────────────────────────────────────────┐
  │                      AWS account                           │
  │  ┌─ Workload plane (EKS) ────────────────────────────────┐ │
  │  │  VPC · EKS managed CP · EC2 workers                   │ │
  │  └───────────────────────────────────────────────────────┘ │
  │  ┌─ CI/CD (GitOps CD) ───────────────────────────────────┐ │
  │  │  Argo CD Principal (hub)  ↔  Agent (on EKS spoke)     │ │
  │  └───────────────────────────────────────────────────────┘ │
  │  ┌─ Services plane (on EKS, via Argo) ───────────────────┐ │
  │  │  DB · Registry · IdP · Auth proxy · OTel · LGTM       │ │
  │  └───────────────────────────────────────────────────────┘ │
  └────────────────────────────────────────────────────────────┘
```

Same diagram as SVG: [docs/architecture.svg](docs/architecture.svg).

### Planes

| Plane | Where it runs | What lives there |
|-------|---------------|------------------|
| **Source of truth** | GitHub (this repo) | EKS CAPA YAML, Flux job, IAM templates, docs |
| **Management** | Kind (`capi-mgmt`) | Flux, CAPI/CAPA controllers, `aws-eks-clusters` job, optional Weave UI |
| **Identity bootstrap** | AWS IAM via CloudFormation | CAPA controllers + EKS CP role + node instance profile |
| **Workload** | AWS EKS (cluster lifecycle) | Managed API/etcd; CAPA-built VPC + worker nodes |
| **Services** | Workloads **on** the EKS cluster | Shared platform services (database, registry, identity, observability, CD agent) — see §7 |
| **CI/CD (GitOps CD)** | Argo CD **Principal** + **Agent** | Continuous delivery of services/apps from git; see §7 |

**Critical rule:** Flux applies **CAPA objects to Kind**. CAPA talks to **AWS** (EKS, EC2, VPC, …). Services plane and app delivery use **Argo CD** (not the Kind CAPA job).

---

## 3. Control flow (implement path)

```text
1. Edit YAML in git (aws_eks cluster, job suspend, or aws_iam template)
2. Push to main
3a. Flux on Kind reconciles:
      - clusters/capi-mgmt           → management config + jobs
      - job aws-eks-clusters
          path ./aws_eks/clusters   → CAPA CRs (Cluster, AWSManagedControlPlane, …)
3b. Operator (when IAM changes):
      aws cloudformation deploy --template-file aws_iam/common.yaml
      aws cloudformation deploy --template-file aws_iam/eks.yaml
      # node instance profile (workers): also capa-iam-ec2 today — see §5
4. CAPA on Kind reconciles CRs → EKS + VPC + worker EC2 in AWS
5. Argo CD delivers **services plane + apps** onto EKS:
   - Principal (hub / control plane) holds Application desired state
   - Agent on the target cluster applies/reconciles to the workload API
```

**Two GitOps roles (do not conflate):**

| Tool | Role in this design |
|------|---------------------|
| **Flux** (on Kind) | Management-plane GitOps — CAPA cluster lifecycle only |
| **Argo CD** (Principal + Agent) | Workload GitOps — services plane + applications on EKS |

**No manual `kubectl apply` of EKS CAPA CRs** for the happy path. Push to `main` is the implement path for cluster objects (`clusters/capi-mgmt/jobs/aws-eks-clusters.yaml`).

IAM is deployed with the AWS CLI from templates in git (YAML-first, not console-first).

---

## 4. Repository map (EKS-focused)

| Path | Owns | Applied by |
|------|------|------------|
| [`clusters/capi-mgmt/`](clusters/capi-mgmt/) | Flux bootstrap, Weave UI, **Flux jobs** | Flux (self) |
| [`clusters/capi-mgmt/jobs/aws-eks-clusters.yaml`](clusters/capi-mgmt/jobs/aws-eks-clusters.yaml) | Job that syncs EKS CAPA path | Flux |
| [`aws_eks/`](aws_eks/) | **Primary** — EKS CAPA cluster manifests | Flux → Kind |
| [`aws_iam/`](aws_iam/) | CAPA IAM CloudFormation | `aws cloudformation deploy` |
| [`aws_ec2/`](aws_ec2/) | Secondary / future mirror of this design | Not the architecture focus |
| [`local/`](local/) | Notes, secrets, reference clones | Never commit |

### Primary Flux job

| Job (`Kustomization`) | Git path | Provisions |
|-----------------------|----------|------------|
| `aws-eks-clusters` | `./aws_eks/clusters` | Amazon EKS + CAPA workers |

Parent management kustomization: `clusters/capi-mgmt/kustomization.yaml`.

Services-plane Git paths are **not yet landed** (architecture target). Prefer a clear tree under the workload (e.g. `aws_eks/services/` or a dedicated Flux Kustomization against the EKS cluster) when implementation starts.

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
| Region / SSH | `PLACEHOLDER_*` | Filled per environment; not committed secrets |

**AWS-managed:** EKS control-plane HA, control-plane patching, etcd.  
**CAPA-managed:** VPC/subnets/NAT pattern (via CAPA defaults + AZ limit), worker EC2 lifecycle, cluster create/update/delete via controllers.

Fields not yet pinned in YAML (rely on CAPA/EKS defaults until we grow the design): API endpoint public/private, control-plane logging, secrets encryption KMS, add-ons as CAPA objects, IRSA/OIDC.

---

## 7. Services plane

Shared **platform services** that run on (or in front of) the EKS workload cluster. They are not CAPA cluster objects; they are the capabilities product teams and operators consume.

**Status:** architecture target (capabilities defined here). Manifests / GitOps wiring not yet in-repo.

### Capability catalog

Industry names are primary; **team names** in parentheses for local vocabulary.

| Capability (industry) | Team name | Product / stack | Role |
|-----------------------|-----------|-----------------|------|
| **Continuous delivery** (GitOps CD) | CI/CD | [Argo CD](https://argo-cd.readthedocs.io/) **Principal** + **Agent** | Deploy/reconcile services & apps from git to clusters |
| **Database platform** (PostgreSQL on Kubernetes) | Data | [CloudNativePG](https://cloudnative-pg.io/) | Cloud-native Postgres operator: HA, backups, failover |
| **OCI container registry** (incl. pull-through cache) | Image Proxy | [Harbor](https://goharbor.io/) | Image store, vulnerability scan, proxy/cache to upstream registries |
| **AuthN/AuthZ proxy** (identity-aware reverse proxy) | Auth/Auth | [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) | Protect UIs/APIs; OIDC login; forward identity headers |
| **Identity provider (IdP)** / SSO & federation | ID Federation | [Keycloak](https://www.keycloak.org/) | Users, realms, OIDC/SAML federation, client registration |
| **Telemetry collection** (instrumentation pipeline) | Obs. Infra | [OpenTelemetry](https://opentelemetry.io/) | SDKs + Collector: traces, metrics, logs → backends |
| **Observability backend** (LGTM stack) | Observability | Grafana · Loki · Tempo · Mimir | Viz + logs + traces + metrics (long-term metrics via Mimir) |

### CI/CD — Argo CD Principal and Agent

Industry language: **GitOps continuous delivery** with a **hub-and-spoke** (control plane + cluster agent) layout. Team name: **CI/CD**.

| Component | Industry terms | Responsibility |
|-----------|----------------|----------------|
| **Argo CD Principal** | Control plane · hub · management Argo CD | Holds Applications / ApplicationSets, connects to git, UI/API, RBAC; orchestrates desired state |
| **Argo CD Agent** | Spoke · cluster agent · in-cluster reconciler | Runs **on the target cluster** (EKS); applies and reconciles resources locally so the hub need not hold long-lived high-privilege cluster-admin into every spoke |

```text
  Git (apps + services manifests)
           │
           ▼
  ┌─────────────────────┐         control channel          ┌──────────────────────┐
  │ Argo CD Principal   │ ◄──────────────────────────────► │ Argo CD Agent        │
  │ (hub / control)     │                                   │ (on EKS spoke)       │
  └─────────────────────┘                                   └──────────┬───────────┘
                                                                       │ reconcile
                                                                       ▼
                                                              EKS services + apps
```

| Concern | Choice for this lab architecture |
|---------|----------------------------------|
| Bootstrap of the EKS cluster itself | **Flux on Kind** + CAPA (unchanged) |
| Delivery of services plane + applications | **Argo CD** Principal + Agent |
| Principal placement (target) | Platform/management host for CD hub (lab may co-locate; production often isolates the hub) |
| Agent placement | **On each EKS workload cluster** (spoke) |
| Auth to Argo UI | Keycloak OIDC + OAuth2 Proxy (same as other operator UIs) |
| Image pulls after deploy | Harbor |

**CI vs CD:** “CI/CD” here emphasizes **CD** (Argo CD). Build/test pipelines (CI) can feed images into **Harbor** and git manifests that Argo reconciles; CI tooling is not fixed in this document yet.

### How they relate

```text
  Git ──► Argo CD Principal ──► Argo CD Agent ──► EKS (services + apps)
                │
                └── UI protected by OAuth2 Proxy ◄── Keycloak (OIDC)

  CI / builders ──► Harbor (OCI registry / pull-through)
                         ▲
  Nodes / deploys ───────┘

  Apps ──► CloudNativePG (Postgres)

  Apps / nodes ──► OpenTelemetry Collector ──► Grafana LGTM
                   (telemetry)                  Loki · Tempo · Mimir
                                                (+ Grafana UI)
```

| Flow | Components |
|------|------------|
| Deploy services/apps | Git change → Argo CD Principal → Agent reconciles on EKS |
| Login to operator UIs | Keycloak issues tokens; OAuth2 Proxy enforces session / OIDC (incl. Argo CD UI) |
| Image supply chain | CI pushes (or proxy-pulls) via Harbor; nodes pull from Harbor |
| Stateful data | Workloads use CloudNativePG-managed Postgres |
| Signals | Apps export OTLP → OpenTelemetry Collector → Mimir / Loki / Tempo; Grafana queries all three |

### Placement

| Decision | Choice |
|----------|--------|
| Host (most services) | Run **on the EKS cluster** produced by CAPA (workload plane) |
| Argo CD Agent | **On EKS** (spoke) |
| Argo CD Principal | CD hub — lab may share platform cluster; treat as distinct role from Flux-on-Kind |
| Apply path for apps/services | **Argo CD**, not Kind CAPA job and not hand `kubectl` |
| Isolation | Prefer dedicated namespaces (and later network policies) per capability |
| Lab sizing | Shared single EKS is fine; production may split hub, platform services, and app clusters |

### Lab vs production (services)

| Capability | Lab target | Production target |
|------------|------------|-------------------|
| Argo CD Principal + Agent | Single hub + agent on lab EKS; git from this org | HA hub, per-cluster agents, SSO, project RBAC, progressive sync |
| CloudNativePG | Single small Postgres cluster; local/object backup optional | Multi-AZ, PITR, encryption, resource quotas |
| Harbor | Single replica / lab storage | HA, replicated storage, signing/policies, pull-through to ECR/Docker Hub |
| OAuth2 Proxy | Protect Grafana / Harbor / Argo / Keycloak admin as needed | Consistent edge auth for all internal tools |
| Keycloak | Single realm, lab IdP | HA, external DB (often CNPG), federation to org IdP |
| OpenTelemetry | DaemonSet or gateway collector, sample traces | Sampling policies, multi-tenant attributes, resource limits |
| LGTM | Single-node or small footprints | HA Mimir/Loki/Tempo, retention, auth via proxy + Keycloak |

---

## 8. Lab vs production targets (EKS substrate)

**Lab is intentional; production is the promotion target.**

| Dimension | Lab (this repo today) | Production target |
|-----------|----------------------|-------------------|
| Management plane | Kind + Flux | Hardened mgmt (or EKS), multi-AZ, backups, restricted API |
| GitOps (cluster lifecycle) | Flux from `main` → Kind/CAPA | Same + PR gates, schema/policy checks |
| GitOps (apps/services) | Argo CD Principal + Agent (target) | HA hub, agents on all spokes, SSO, AppProjects |
| VPC / NAT | 2 AZs / 2 NATs | 3 AZs; consider VPC endpoints to cut NAT |
| Workers | 1 × `t3.large` | ≥2–3 multi-AZ (services plane needs headroom) |
| EKS API access | CAPA defaults (not explicit in YAML) | Private endpoint preferred; public CIDR allowlist if needed |
| Control-plane logs | Not explicit | API, audit, authenticator, controller, scheduler → CloudWatch |
| Secrets encryption | Not explicit | Customer-managed KMS key |
| Node access | SSH key placeholders | SSM only; no standing SSH |
| Pod identity | Not first-class | IRSA or EKS Pod Identity (required cleanly for services) |
| Observability | Services plane target (OTel + LGTM) | Same stack, production HA/retention |
| IAM controllers | CAPA-wide policies | Tag/condition scope + access reviews |
| Cost | Documented 2-AZ floor | Budgets, tags, teardown automation |
| DR | None | Multi-region strategy only if business requires |

---

## 9. Trust boundaries

| Boundary | Description |
|----------|-------------|
| **Git → Kind** | Flux reconciles only declared paths (`capi-mgmt`, `aws_eks/clusters`) |
| **Kind → AWS** | CAPA controllers use controller IAM; create EKS, VPC, EC2, … |
| **EKS workload API** | Separate kubeconfig; services plane + apps do not run on Kind |
| **GitOps CD** | Argo CD Principal is the control plane for app/service desired state; Agent is the privileged reconciler **on** the spoke — limit who can change Application specs in git/hub |
| **Identity (services)** | Keycloak is the cluster IdP; OAuth2 Proxy is the enforcement edge for UIs (including Argo CD) |
| **Data / registry** | CNPG and Harbor hold sensitive state — network policy + secrets discipline |
| **Telemetry** | OTel path should not become an unauthenticated write API from the internet |
| **Human → AWS** | IAM CFN deploys and break-glass; secrets only under `local/` (gitignored) |

---

## 10. Design principles

1. **EKS is the product path** — architecture and docs optimize for CAPA → EKS.  
2. **Services plane is first-class** — shared capabilities are named and owned, not ad-hoc apps.  
3. **YAML first** — AWS and platform changes come from git.  
4. **Flux → Kind/CAPA (clusters); Argo CD Principal+Agent → EKS (services/apps)** — do not use one tool for both jobs without intent.  
5. **IAM is central for CAPA** — `aws_iam/` only; pod/service identity is separate.  
6. **Cost-aware lab defaults** — 2 AZ / 2 NAT called out next to the knobs.  
7. **No secrets in git**.  
8. **Document lab vs prod** — §7 (services) and §8 (substrate).  
9. **`aws_ec2` follows later** — same GitOps/IAM patterns; not dual primary architectures.

---

## 11. Related docs

| Doc | Topic |
|-----|--------|
| [README.md](README.md) | Repo layout and rules |
| [aws_eks/README.md](aws_eks/README.md) | EKS path operations |
| [aws_iam/README.md](aws_iam/README.md) | IAM stacks and deploy order |
| [clusters/capi-mgmt/README.md](clusters/capi-mgmt/README.md) | Flux jobs, Weave UI |
| [docs/architecture.svg](docs/architecture.svg) | System diagram (EKS + services) |

---

## 12. Evolution

Prefer order:

1. Harden EKS substrate (endpoint, logging, encryption, worker capacity for services)  
2. Land **Argo CD Principal + Agent** (CD path for everything that runs on EKS)  
3. Land **Services plane** via Argo (Keycloak → OAuth2 Proxy → Harbor → CNPG → OTel → LGTM)  
4. CI validation of CAPA + services manifests; CI → Harbor image flow  
5. IRSA / Pod Identity for each service  
6. Then: reshape `aws_ec2/` as a clone of this operating model  

Update this file and [docs/architecture.svg](docs/architecture.svg) when topology or the services catalog changes.
