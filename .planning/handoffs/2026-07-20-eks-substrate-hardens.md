# Handoff: EKS substrate hardens (dev mode)

**Date:** 2026-07-20  
**Repo:** `capi` (`main` local work — **do not push** while Flux would apply AWS)  
**Mode:** Development — templates and CAPA YAML only; no AWS apply from this session.

---

## Constraints (carry forward)

1. **No git push** while `aws_eks/clusters` could provision (or until `resources: []` stays empty on remote).  
2. **No AWS deploys** of new stacks until intentionally leaving pure-dev.  
3. Flux path `aws-eks-clusters` tracks `./aws_eks/clusters` — empty `resources` = no cluster CRs.

---

## Done this session (local)

### WA Do-first substrate hardens in `aws_eks/clusters/capi-eks-1.yaml`

| Control | Implementation |
|---------|----------------|
| CP logging | All five → CloudWatch |
| Endpoint | `private: true`, `public: true`, `publicCIDRs` via kustomize |
| Encryption | `encryptionConfig` → `alias/cluster-api-provider-aws-eks-secrets` |
| OIDC | `associateOIDCProvider: true` |
| SSH / bastion | `sshKeyName: ""`, bastion off; workers `publicIP: false` |
| Tags | Project / Environment / CostCenter / ManagedBy |
| AL2023 bootstrap | `cloudInit.insecureSkipSecretsManager: true` |

### Supporting templates (not deployed)

| Path | Purpose |
|------|---------|
| `aws_eks/kms/eks-secrets-cmk.yaml` | CMK + alias for secrets encryption |
| `aws_cost/lab-budget.yaml` | Monthly budget (optional email) |
| `aws_iam/ec2-self-managed.yaml` | Node role + `AmazonSSMManagedInstanceCore` |

### Docs

- `ARCHITECTURE.md` §6 knobs + §8 lab/prod matrix  
- `aws_eks/**/README`, `aws_iam/README`, root `README`  
- kustomize: dropped SSH param; added `PUBLIC_API_CIDR`  
- **`resources: []` unchanged** (safe)

---

## Live environment (unchanged intent)

| Component | Status (last known) |
|-----------|---------------------|
| Kind `capi-mgmt` | Up (lab mgmt experimental) |
| IAM stacks `capa-iam-{common,ec2,eks}` | CREATE_COMPLETE |
| EKS workload cluster | None (Flux resources empty) |
| New CMK / budget stacks | **Not deployed** |

---

## Next session options

1. Local review / dry-run kustomize of hardened YAML (no push).  
2. When ready for AWS: deploy KMS → (optional budget) → set `PUBLIC_API_CIDR` → enable resources → push.  
3. Continue WA: Services plane design, management decision, or pillar deep-dive.  
4. Commit locally only if desired — **still no push** until AWS create is intentional.

---

## Prior handoff

`.planning/handoffs/2026-07-13-aws-eks-next.md` — IAM split + EKS scaffold (mostly complete; superseded for “what’s next”).
