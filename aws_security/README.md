# Security baseline (production design)

Controls that raise the **Security** pillar toward WA ≥ 4.0. **Not Flux-wired.**

**Architecture:** CloudTrail, GuardDuty, and Config are on the **AWS Services rail** (`docs/architecture.svg`). Trail/Config delivery uses rail **S3**. Observability remains **OpenTelemetry + LGTM**; EKS CP logs use rail **CloudWatch (CP Logs Only)** then OTel → Loki.

| Stack / path | Purpose | Pillar BP themes |
|--------------|---------|------------------|
| [`detection.yaml`](detection.yaml) | CloudTrail, GuardDuty, Config, encrypted log buckets | Detection, audit, config history |
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
| **IRSA / Pod Identity** | Karpenter, OTel gateway (CW logs read), platform services — **required** for production |
| Human | IAM Identity Center / IAM roles; SSM for nodes; no standing SSH |

## Secrets (platform)

**OpenBao** + **External Secrets Operator** only. No AWS Secrets Manager for app/platform secrets.

## Incident readiness (design)

| Control | Location |
|---------|----------|
| Audit trail | **CloudTrail** → **S3 (CMK)** (optional later ship to Loki) |
| Threat findings | **GuardDuty** |
| Config drift | **Config** recorder |
| Cluster / app ops | **OpenTelemetry** + **Grafana LGTM** — `aws_eks/services/lgtm/` |
| EKS CP logs | CAPA → **CloudWatch (CP Logs Only)** → OTel gateway → **Loki** |
| Response | [`incident-response.md`](incident-response.md) |
