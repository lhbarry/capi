# Handoff: CAPA lab → next session (`aws_eks` + IAM layout)

**Date:** 2026-07-13 (updated end of day)  
**Repo:** `lhbarry/capi` (`main`)  
**Resume:** open this file from `/home/lonny/Devel/Git/capi` (or `/pickup`).

---

## First task tomorrow (BLOCKING — decide at session start)

### Decide IAM CloudFormation layout before any EKS work

**Do not** `clusterctl generate` / apply `aws_eks` cluster YAML until this is decided.

#### Why this is first

Current CAPA IAM is **one monolith** stack. It mixes common controller IAM, EC2 self-managed node/CP profiles, and EKS-specific bits. Next path is `aws_eks`; user wants a **decision** on cutting into **three templates** (common / ec2 / eks) vs keeping one stack.

#### What’s in the monolith today (11 resources)

| Bucket | Resources (`*.cluster-api-provider-aws.sigs.k8s.io`) | Needed for |
|--------|------------------------------------------------------|------------|
| **Common** | Role + policy (+ profile) **controllers** | Kind CAPA for both paths |
| **EC2 self-managed** | **control-plane** + **nodes** (role, policy, instance profile) | `aws_ec2` kubeadm CAPA |
| **EKS** | Role **eks-controlplane** + policy **controllers-eks** | `aws_eks` CAPA |

Stack name: `cluster-api-provider-aws-sigs-k8s-io`  
Template: `aws_ec2/iam/cluster-api-provider-aws-sigs-k8s-io.yaml`  
Live status: **CREATE_COMPLETE** · **$0** billable  

#### Options (pick one)

1. **Split three stacks (proposed for teaching / boundaries)**  
   - e.g. `aws_iam/common.yaml`, `aws_iam/ec2-self-managed.yaml`, `aws_iam/eks.yaml`  
   - Deploy: always **common**; add **ec2** and/or **eks**  
   - Cross-stack: attach `controllers-eks` → controllers role when EKS enabled  
2. **Keep one CAPA stack** — reuse for both paths; unused IAM idle at $0  
3. **Two stacks** — common + path (ec2 \| eks)  
4. **Defer cut** until after first EKS generate shows real needs  

#### Decision record

| Field | Value |
|-------|--------|
| **Chosen option** | **1 — Split three stacks** |
| **Rationale** | Clear common / ec2 / eks boundaries for teaching + selective deploy |
| **Stack names** | `capa-iam-common`, `capa-iam-ec2`, `capa-iam-eks` |
| **Repo paths** | **`aws_iam/` only** (`common.yaml`, `ec2-self-managed.yaml`, `eks.yaml`) — not under `aws_ec2/` |
| **Deploy order** | common → ec2 and/or eks |
| **Existing monolith** | Deleted; do not restore under `aws_ec2/iam` |

#### If option 1 — implement sketch

1. Create `aws_iam/` shared tree.  
2. Cut template by ownership table.  
3. Docs: `aws_ec2` → common+ec2; `aws_eks` → common+eks (+ nodes if workers still EC2).  
4. Apply only via `aws cloudformation deploy --template-file` (YAML-first).  
5. Then scaffold `aws_eks/`.

---

## Second task (after IAM decision): `aws_eks`

```text
aws_eks/
  README.md
  clusters/     # EKS-oriented CAPA manifests
```

1. Generate CAPA EKS template (`clusterctl`) into git.  
2. Flux path: new Kustomization or document apply.  
3. CAPA on Kind → EKS in AWS (same GitOps rule as EC2).  
4. Document CNI/CCM differences vs `aws_ec2`.

---

## Session completed (aws_ec2)

| Milestone | Result |
|-----------|--------|
| Kind `capi-mgmt` | Management plane |
| Flux + Weave UI | GitOps on Kind; UI port-forward 9001 |
| CAPA init | controllers on Kind |
| IAM CFN from YAML | GitOps-corrected (tear+redeploy from file) |
| Workload `capi-lab-1` | EC2 CAPA cluster (v1.34.1) |
| CNI + CCM | Calico + fixed CCM DS under `aws_ec2/clusters/addons/` |
| Single NAT | `availabilityZoneUsageLimit: 1` in manifest |
| Teardown | Cluster deleted; EC2 terminated; VPC/NAT/NLB gone |

### Principles (carry forward)

1. **AWS changes only from tracked YAML.**  
2. Flux → **Kind**; CAPA → **AWS**.  
3. Workload addons apply to **workload** API (`addons/`), not Kind Flux path.  
4. Lab cost: **1 AZ / 1 NAT** for next EC2 create.

---

## Live environment snapshot (2026-07-13 EOD)

| Component | Status |
|-----------|--------|
| GitHub `main` | includes handoff + single-NAT + addons |
| Kind `capi-mgmt` | **Up** |
| Flux `flux-system` | **Running**, tracks latest |
| Flux `aws-ec2-clusters` | **SUSPENDED** (won’t recreate cluster) |
| Workload Cluster CR | **None** |
| AWS EC2/VPC/NAT/NLB for capi-lab-1 | **Gone** (instances terminated) |
| IAM CFN monolith | **CREATE_COMPLETE** |
| SSH key `Lonny_EtcConsulting` | Pre-existing, free |
| Kind orphans (optional) | CRS/ConfigMaps for CCM/CSI may remain in `default` |

### Useful commands

```bash
kubectl config use-context kind-capi-mgmt
flux get kustomizations -A
# flux resume kustomization aws-ec2-clusters -n flux-system   # only if recreating EC2 cluster

aws cloudformation describe-stacks --region us-east-2 \
  --stack-name cluster-api-provider-aws-sigs-k8s-io \
  --query 'Stacks[0].StackStatus'
```

### Key paths

| Path | Purpose |
|------|---------|
| `aws_iam/` | **Sole** CAPA IAM CFN (common / ec2 / eks) |
| `aws_ec2/clusters/capi-lab-1.yaml` | EC2 CAPA cluster (1 NAT layout) |
| `aws_ec2/clusters/addons/` | Calico + CCM DS (workload `kubectl apply -k`) |
| `aws_eks/` | EKS CAPA scaffold |
| `clusters/capi-mgmt/` | Flux + Weave + aws-ec2-clusters Kustomization |
| `local/Process.md` | Machine process log (**gitignored**) |
| `graphify-out/` | Project knowledge graph (see below) |
| `README.md` | Repo map |

---

## Graphify

Rebuilt at end of session (AST only, no LLM):

```bash
cd /home/lonny/Devel/Git/capi
graphify update . --force
```

| Artifact | Notes |
|----------|--------|
| `graphify-out/graph.json` | 51 nodes · 45 edges · 7 communities |
| `graphify-out/graph.html` | Interactive view |
| `graphify-out/GRAPH_REPORT.md` | Hubs/communities report |
| Built from | commit near handoff refresh |

God hubs (from report): IAM GitOps docs, this handoff, workload clusters GitOps, `aws_ec2` source of truth, **IAM layout decision**.

After substantive doc/YAML changes tomorrow:

```bash
graphify update . --force
# optional: graphify label .   # if API key set for community names
```

---

## Explicit non-goals at session start

- No EKS generate/apply before IAM decision.  
- No accidental `capi-lab-1` recreate (Kustomization suspended on purpose).

---

## Checklist for next session

- [x] **Decide** IAM layout → three stacks under `aws_iam/`  
- [x] Implement `aws_iam/` templates + docs; monolith removed from repo tree  
- [ ] Scaffold `aws_eks/`  
- [ ] Generate EKS CAPA YAML → git  
- [ ] Wire Flux / apply path for EKS  
- [ ] `graphify update .` after layout lands  
- [ ] Optional: clean Kind CRS/ConfigMap orphans  

---

*IAM three-template cut is the first agenda item. Graphify refreshed for resume context.*
