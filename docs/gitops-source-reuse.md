# GitOps source reuse — vSphere SCKE → AWS Services plane

## Intent (locked)

Almost every capability on the architecture diagram already has a **GitLab project** with:

- Helm **chart version pins**
- **Proven values** from production-like operation on **vSphere-hosted SCKE** (notably the **SCKE:Observability** cluster and sibling Services)

This CAPA/AWS architecture **does not reinvent** those platform packages. It **reuses** those GitOps sources as the installable desired state for the **Services** (and related Workload) plane on EKS.

| Layer | What lives where |
|-------|------------------|
| **GitLab (existing)** | Charts, chart versions, proven values, app-of-apps patterns for Keycloak, OAuth2 Proxy, Harbor, OpenBao, ESO, CNPG, OTel, LGTM, Velero, Argo, Knative, … |
| **This repo (`capi`)** | CAPA/EKS substrate, IAM, AWS rail (EFS/EBS/S3/CW-CP/Trail/GD/Config), three-cluster topology, Argo Principal/Agent placement, **AWS deltas** (IRSA, storage classes, private API, S3 BSL, …) |
| **Argo CD (Services)** | Points at GitLab sources (+ this repo for substrate-related apps) and reconciles onto EKS |

```text
  vSphere SCKE:Observability (+ Services peers)
           │  proven charts + values
           ▼
       GitLab projects  ──────────────────────────────┐
           │                                          │
           │  reuse (same chart pins / values baseline)│
           ▼                                          │
  AWS Services EKS  ◄── Argo Principal + AppController ┘
  (+ AWS-only overlays: IRSA, SC, S3 BSL, private networking)
```

## WAF / OPS scoring implication

Finding “Services peers mostly design, not installable desired state” in **this repo alone** is incomplete.

| Misread | Correct read |
|---------|----------------|
| Peers have no installable state | Installable state lives primarily in **GitLab** from vSphere SCKE |
| Must re-author all charts under `aws_eks/services/` | Prefer **reference + thin AWS overlay**, not chart rewrite |
| OPS gap = missing Helm charts | Residual OPS gap = **wire** Argo → GitLab sources, document map, land AWS deltas, prove first sync on EKS |

## What this repo should contain for peers

For each diagram capability:

1. **Source map** — GitLab project / path / chart version (or monorepo path) used on vSphere  
2. **AWS overlay** — only deltas required on EKS (IRSA annotations, StorageClass, ingress class, S3 BSL, region, resource tags)  
3. **Argo Application** (or documented app-of-apps entry) targeting that source  
4. **VERSION / pin** — same chart pin as proven unless intentionally bumped with a decision note  

**Do not** require full chart vendoring into `capi` unless policy demands air-gapped mirrors (Harbor already covers image supply).

## Capability → expected GitLab source (fill in)

Owner: map each diagram box to the existing GitLab project. Paths below are placeholders until inventory is filled from vSphere SCKE.

| Diagram / catalog | Expected source origin | Status in this repo |
|-------------------|------------------------|---------------------|
| Argo CD | GitLab (vSphere Services) | Placement + values overlays in `aws_eks/services/argocd/` |
| Karpenter | N/A on vSphere the same way — AWS-native | Manifests in `aws_eks/services/karpenter/` |
| Velero | GitLab (proven) + **S3** BSL overlay | Schedules/BSL sketches in `aws_eks/services/velero/` |
| Keycloak | GitLab | Map + AWS overlay **TBD** |
| OAuth2 Proxy | GitLab | Map + AWS overlay **TBD** |
| Harbor | GitLab | Map + AWS overlay **TBD** |
| OpenBao | GitLab | Map + AWS overlay **TBD** |
| External Secrets Operator | GitLab | Map + AWS overlay **TBD** (OpenBao only backend) |
| CloudNativePG | GitLab | Map + AWS overlay **TBD** (EBS CSI) |
| OpenTelemetry | GitLab (Observability) | Gateway/agent sketches + CW CP path in `lgtm/collectors/` |
| Grafana LGTM | GitLab (SCKE:Observability) | Alerts + architecture; prefer Observability chart pins |
| Knative | GitLab | Workload plane; map **TBD** |

## AWS-only deltas (always expected)

Reuse of vSphere values is the baseline. Typical EKS adjustments (not rewrites):

| Concern | Delta |
|---------|--------|
| Identity | IRSA / Pod Identity instead of vSphere cloud-provider patterns |
| Storage | EBS CSI / EFS CSI StorageClasses vs vSphere CNS/CSI |
| Backup target | Velero **S3** (diagram rail) |
| CP logs | CloudWatch (CP Logs Only) → OTel → Loki |
| Network | Private EKS API; NLB/ingress patterns for AWS |
| Secrets | Keep **OpenBao + ESO** only (no AWS Secrets Manager for app secrets) |

## Next steps to close the residual OPS gap

1. Fill the **capability → GitLab** table (project URL, chart version, values path).  
2. Document Argo repo credentials / deploy-key pattern (Services Principal).  
3. Add thin Application manifests (or app-of-apps root) under this repo or an existing GitLab root app.  
4. First-wave promote order: Argo → OpenBao/ESO → Keycloak/OAuth2 → Harbor → LGTM/OTel → CNPG → Velero (adjust if vSphere order differs).  
5. Re-score OPS after first successful Argo sync of a peer from GitLab onto Services EKS.

## Related

- Catalog: [ARCHITECTURE.md](../ARCHITECTURE.md) §7  
- Inventory: [architecture-inventory.md](architecture-inventory.md)  
- Scorecard: [wa-scorecard.md](wa-scorecard.md)  
- Services tree: [aws_eks/services/README.md](../aws_eks/services/README.md)  
