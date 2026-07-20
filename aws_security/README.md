# Security baseline (production design)

Controls that raise the **Security** pillar toward WA ≥ 4.0. **Not Flux-wired.**

**Scope note:** Detection templates here are **account-level** (CloudTrail→**S3**, GuardDuty, Config). They are **not** additions to the architecture diagram’s AWS Services rail (EFS · EBS · S3 only). Trail storage uses diagram **S3**. Observability remains **OpenTelemetry + LGTM** on the Services plane.

| Stack / path | Purpose | Pillar BP themes |
|--------------|---------|------------------|
| [`detection.yaml`](detection.yaml) | CloudTrail, GuardDuty, Config, encrypted log bucket | Detection, audit, config history |
| [`../aws_iam/karpenter-irsa.yaml`](../aws_iam/karpenter-irsa.yaml) | Karpenter controller IRSA role (Workload) | Least privilege identity |
| [`../aws_eks/security/`](../aws_eks/security/) | PSS labels, NetworkPolicies (Services Argo) | Network/compute protection |
| CAPA cluster YAML | Private EKS API, CP logs, CMK secrets, OIDC, encrypted volumes, no SSH | Foundations, data, network |

## Deploy order (with cluster create)

```text
1. aws_iam CAPA stacks (existing)
2. aws_eks/kms CMK
3. aws_security/detection.yaml
4. Management → Services → Workload CAPA create
5. aws_iam/karpenter-irsa.yaml (after Workload OIDC issuer known)
6. kubectl apply -k aws_eks/security/  (Services + Workload as applicable)
```

## Private EKS API

Both CAPA EKS clusters use **`endpointAccess.private: true`, `public: false`**.  
Management (Turtles/CAPA) **must** reach private EKS endpoints (same VPC, peering, Transit Gateway, or PrivateLink). No public Kubernetes API.

## Identity model

| Identity | Use |
|----------|-----|
| CAPA controllers | IAM on Management (instance profile / IRSA on RKE2) |
| Node instance profile | CAPA nodes + SSM; **not** for app AWS access |
| **IRSA / Pod Identity** | Karpenter, Argo (as needed), platform services — **required** for production |
| Human | IAM Identity Center / IAM roles; SSM for nodes; no standing SSH |

## Incident readiness (design)

| Control | Location |
|---------|----------|
| Audit trail | CloudTrail → **S3 (CMK)** only (optional later ship to **Loki**) |
| Threat findings | GuardDuty |
| Config drift | AWS Config recorder |
| Cluster / app ops | **OpenTelemetry** + **Grafana LGTM** (diagram) — `aws_eks/services/lgtm/` |
| EKS CP logs | CAPA enables CP logging; **OpenTelemetry Collector** exports to **Loki** (no Fluent Bit) |
| Response | [`incident-response.md`](incident-response.md) |
