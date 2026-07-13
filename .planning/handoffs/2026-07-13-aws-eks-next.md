# Handoff: CAPA lab → next session (`aws_eks` + IAM layout)

**Date:** 2026-07-13  
**Repo:** `lhbarry/capi` (`main` @ `12456c5`)  
**Resume:** from this directory with `/pickup` or open this file.

---

## Session goal completed (aws_ec2)

Proved GitOps path:

```text
GitHub (lhbarry/capi) → Flux on Kind (capi-mgmt) → CAPA → AWS EC2 workload cluster
```

Workload cluster `capi-lab-1` was brought up (v1.34.1, Calico + CCM), then **torn down**. AWS cluster resources are gone. Kind + Flux + CAPA controllers remain.

---

## First task tomorrow (BLOCKING DECISION)

### Decide IAM CloudFormation layout before EKS work

**Do not generate/apply `aws_eks` cluster YAML until this is decided.**

#### Context

Current stack (monolith, still in account, **$0 bill**):

| Stack | Template path | Status |
|-------|---------------|--------|
| `cluster-api-provider-aws-sigs-k8s-io` | `aws_ec2/iam/cluster-api-provider-aws-sigs-k8s-io.yaml` | `CREATE_COMPLETE` |

That template mixes three concerns (11 resources):

| Bucket | Resources (names under `*.cluster-api-provider-aws.sigs.k8s.io`) |
|--------|-------------------------------------------------------------------|
| **Common** | Role + policy (+ instance profile) **controllers** |
| **EC2 self-managed** | **control-plane** + **nodes** (role, policy, instance profile each) |
| **EKS** | Role **eks-controlplane** + policy **controllers-eks** |

#### Options to decide

1. **Split three stacks (proposed / preferred for teaching)**  
   - Layout e.g. `aws_iam/common.yaml`, `aws_iam/ec2-self-managed.yaml`, `aws_iam/eks.yaml`  
   - Deploy: always **common**; add **ec2** and/or **eks** per path  
   - Cross-stack: attach `controllers-eks` policy to **common** controllers role when EKS path is enabled  
   - Tradeoff: you own the cut; `clusterawsadm print-cloudformation-template` is no longer 1:1 with “the” stack  

2. **Keep one CAPA stack**  
   - Reuse existing for both `aws_ec2` and `aws_eks`  
   - Fastest; unused IAM bits idle at $0  

3. **Two stacks**  
   - common + path (ec2 \| eks) — middle ground  

4. **Defer cut until after first EKS `clusterctl generate`**  
   - Reuse stack for first EKS lab, then split based on what CRs actually need  

#### Decision record (fill in at start of session)

| Field | Value |
|-------|--------|
| **Chosen option** | _TBD — decide at start of next session_ |
| **Rationale** | |
| **Stack names** | |
| **Repo paths** | |
| **Deploy order** | |
| **What to do with existing monolith stack** | leave / delete / migrate |

#### If option 1 is chosen — implementation sketch

1. Create `aws_iam/` (shared; not under only `aws_ec2/`).  
2. Cut current template into three files by resource ownership (table above).  
3. Document:  
   - `aws_ec2` needs **common + ec2**  
   - `aws_eks` needs **common + eks** (and nodes profile if workers still use CAPA EC2 machines)  
4. Deploy with `aws cloudformation deploy --template-file …` only (no blind `clusterawsadm create`).  
5. Update READMEs; optionally delete or leave monolith stack after cutover.  
6. Then proceed to `aws_eks/` cluster manifests.

---

## Second task (after IAM decision): `aws_eks`

Mirror `aws_ec2/` structure:

```text
aws_eks/
  README.md
  clusters/          # CAPA EKS-oriented Cluster / AWSManagedControlPlane / etc.
  # iam/ only if path-specific notes; prefer aws_iam/ for CFN
```

High-level:

1. `clusterctl generate` with CAPA **EKS** template (pin versions).  
2. YAML-first under `aws_eks/`; Flux path decision (new Kustomization or shared).  
3. Apply via Kind CAPA → AWS EKS (not “Flux applies to AWS directly”).  
4. Document differences vs EC2 path (CNI/CCM often different on EKS).

**Assumption to validate after IAM decision:** same CAPA controllers on Kind; EKS may still use `nodes.*` IAM if workers are EC2 machine pools.

---

## Current environment snapshot (end of 2026-07-13)

| Component | Status |
|-----------|--------|
| GitHub `main` | `12456c5` — single-AZ (`availabilityZoneUsageLimit: 1`) for next EC2 create |
| Kind `capi-mgmt` | Up |
| Flux | Up; **`aws-ec2-clusters` SUSPENDED** (prevents recreate) |
| Flux last applied `aws-ec2-clusters` | `cef0233` (older than HEAD single-NAT commit) |
| Workload `capi-lab-1` | **Deleted** (no Cluster; EC2 terminated; VPC/NAT/NLB gone) |
| IAM CFN monolith | **CREATE_COMPLETE** (keep or migrate after decision) |
| SSH key | `Lonny_EtcConsulting` (pre-existing; free) |
| Orphans on Kind (optional clean) | CRS `crs-ccm`/`crs-csi` + addon ConfigMaps in `default` may remain |

### Principles (carry forward)

1. **All AWS changes from tracked YAML** (no blind bootstrap CLIs as source of truth).  
2. Flux → **Kind**; CAPA → **AWS**.  
3. Workload CNI/CCM live under addons applied to **workload** API (or CRS), not blindly on Kind.  
4. Lab cost: **1 AZ / 1 NAT** for EC2 path (`availabilityZoneUsageLimit: 1`).

### Key paths

| Path | Purpose |
|------|---------|
| `aws_ec2/clusters/capi-lab-1.yaml` | EC2 CAPA cluster (1 NAT layout ready) |
| `aws_ec2/clusters/addons/` | Calico + fixed CCM DS (workload apply) |
| `aws_ec2/iam/` | Current monolith CAPA IAM template + README |
| `clusters/capi-mgmt/` | Flux bootstrap + Weave UI + `aws-ec2-clusters` Kustomization |
| `local/Process.md` | Machine process log (**gitignored**) |

### Useful commands

```bash
kubectl config use-context kind-capi-mgmt
flux get kustomizations -A
# Resume EC2 path only when intended:
# flux resume kustomization aws-ec2-clusters -n flux-system

aws cloudformation describe-stacks --region us-east-2 \
  --stack-name cluster-api-provider-aws-sigs-k8s-io \
  --query 'Stacks[0].StackStatus'
```

---

## Explicit non-goals for start of next session

- Do not start EKS cluster generate/apply before IAM layout decision.  
- Do not recreate `capi-lab-1` unless intentional (Kustomization is suspended for a reason).

---

## Checklist for next agent / human

- [ ] **Decision:** IAM 3-way split vs one stack vs two vs defer (fill decision record above)  
- [ ] If split: implement `aws_iam/` + deploy order + docs; handle existing monolith  
- [ ] Scaffold `aws_eks/`  
- [ ] Generate EKS CAPA manifests into `aws_eks/clusters/`  
- [ ] Wire Flux (or document apply path) for EKS objects  
- [ ] Optional: clean Kind CRS/ConfigMap orphans; optional: document EC2 recreate with 1 NAT  

---

*Handoff written so the IAM template cut is the first agenda item, not an afterthought mid-EKS.*
