# Handoff: EKS substrate hardens (dev mode)

**Date:** 2026-07-20  
**Repo:** `capi`  
**Mode:** Development — **do not `git push`** (Flux on Kind tracks `main` → AWS path when resources enabled).  
**Local commit:** `c88ec56` — *Harden EKS CAPA substrate for WA lab posture (local only)*  
**Branch:** `main` ahead of `origin/main` by ≥1 (push only when AWS create is intentional).

---

## Constraints (carry forward)

1. **No git push** until you intend cloud changes (or confirm remote still has `resources: []`).  
2. **No AWS deploys** of new stacks until intentionally leaving pure-dev.  
3. Flux `aws-eks-clusters` → `./aws_eks/clusters` — keep **`resources: []`**.

---

## Done

### WA Do-first in `aws_eks/clusters/capi-eks-1.yaml`

| Control | Implementation |
|---------|----------------|
| CP logging | All five → CloudWatch |
| Endpoint | Private + public + `publicCIDRs` (kustomize) |
| Encryption | `alias/cluster-api-provider-aws-eks-secrets` |
| OIDC | `associateOIDCProvider: true` |
| SSH / bastion | Empty keys; bastion off; workers `publicIP: false` |
| Tags | Project / Environment / CostCenter / ManagedBy |
| AL2023 | `insecureSkipSecretsManager: true` |

### Supporting templates (not deployed)

| Path | Purpose |
|------|---------|
| `aws_eks/kms/` | CMK + alias for secrets encryption |
| `aws_cost/` | Monthly budget CFN |
| `aws_iam/ec2-self-managed.yaml` | Node SSM managed policy (live stack not updated) |

### Docs / candidates

- `ARCHITECTURE.md` §6, §8, §12 evolution  
- Platform candidates: KMS + CloudWatch → `hybrid`; IRSA foundation noted  
- Server dry-run against Kind CRDs passed  

---

## Live environment

| Component | Status |
|-----------|--------|
| Kind `capi-mgmt` | Experimental lab mgmt (up) |
| IAM `capa-iam-{common,ec2,eks}` | CREATE_COMPLETE (SSM policy not yet redeployed) |
| EKS cluster | None (`resources: []`) |
| CMK / budget stacks | Not deployed |
| Git | Local commit only; **not pushed** |

---

## Next (pick one)

### A — Stay pure-dev (recommended until ready for $)

1. Local CI-ish checks (kubeconform / kustomize script) without Flux enable.  
2. Architecture: decide **management plane**, or disposition more `platform-candidates`.  
3. Design-only Services plane (Argo CD) manifests under a non-Flux path or still-empty kustomize.  
4. Pillar deep-dive `/security-assessment` or re-score after hardens.

### B — Leave pure-dev (creates AWS when done end-to-end)

1. Deploy `aws_eks/kms` CMK.  
2. Redeploy `capa-iam-ec2` (SSM on nodes).  
3. Optional `aws_cost` budget + email.  
4. Set real `PUBLIC_API_CIDR` in kustomization.  
5. `resources: [capi-eks-1.yaml]` → commit → **push** (Flux creates EKS).

---

## WA score delta (lab, code-as-evidence)

| | Before hardens | After (YAML committed, not live) |
|--|----------------|----------------------------------|
| Overall | ~2.1 | **~2.6–2.8** (design+YAML; live still lacks CMK deploy) |
| SEC | 1.5 | **~2.3** (logging/encrypt/endpoint/SSH explicit) |
| COST | 2.5 | **~2.8** (tags + budget template) |
| OPS | 2.5 | **~2.7** (documented knobs + candidates) |

Larger jump (~3.0+) needs: live CMK, Services/Argo, IRSA per service, backups, mgmt decision.

---

## Safety checklist before any push

- [ ] `aws_eks/clusters/kustomization.yaml` has `resources: []` **or** you accept EKS create  
- [ ] `PUBLIC_API_CIDR` is a real `/32` (not `YOUR_PUBLIC_IP/32` or `0.0.0.0/0`)  
- [ ] CMK stack exists if encryptionConfig is enabled  
- [ ] Cost floor understood (2 NAT + EKS + worker + CloudWatch logs)
