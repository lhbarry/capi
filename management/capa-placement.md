# CAPI / CAPA placement relative to Rancher

## Decision

| Component | Where it runs |
|-----------|----------------|
| **RKE2** | Management EC2 nodes (Ubuntu) — local/upstream Kubernetes |
| **Rancher Manager** | **Local cluster** (Helm on RKE2) — UI/API, auth, multi-cluster mgmt |
| **CAPI + CAPA** | **Local cluster** as workloads (controllers in e.g. `capi-system` / `capa-system`) |
| **CAPA Cluster CRs** | Applied to **local** cluster API; CAPA creates **downstream EKS** in AWS |
| **Argo CD (apps)** | **Downstream** EKS Services plane — not on management (design) |

```text
┌─ Management (Ubuntu 24.04 × 3, RKE2 + Rancher) ─────────────┐
│  Rancher Manager  (Helm)                                      │
│  CAPI + CAPA                                                  │
│  Applies: aws_eks/clusters/services + workload                │
└────────────┬───────────────────────────────┬──────────────────┘
             │                               │
             ▼                               ▼
┌─ Services EKS ─────────────┐   ┌─ Workload EKS ──────────────┐
│  capi-eks-services         │   │  capi-eks-workload          │
│  Principal+AppController   │   │  Agent → Principal          │
│  CAPA MD × 5 Reserved      │   │  Karpenter (only here)      │
└────────────────────────────┘   └─────────────────────────────┘
```

## Why CAPI/CAPA on the local Rancher cluster

1. **Single management plane** — operators use Rancher + kubectl against local for cluster lifecycle.  
2. **CAPA needs continuous reconciliation** — belongs next to other control-plane controllers, not on Kind.  
3. **IAM** — CAPA controllers use `aws_iam/` roles (instance profile / IRSA on management nodes or dedicated IRSA once OIDC exists on RKE2). Initial path: **instance profile** on the three management EC2 nodes with CAPA controller policies (or a dedicated CAPA role attached to those instances).  
4. **Separation of duties** — app GitOps (Argo) stays on Services plane; cluster GitOps/apply for CAPA CRs can be:  
   - `kubectl apply` / CI from git, or  
   - Rancher continuous delivery / Fleet, or  
   - GitOps agent on local (optional later).

## Install order (after RKE2 + Rancher healthy)

1. Install **clusterctl** targets matching CAPA version used by this repo.  
2. `clusterctl init --infrastructure aws` (or Helm charts) on **local** kubeconfig.  
3. Ensure management node IAM (or IRSA) can assume CAPA controller permissions (`aws_iam/common.yaml` + `eks.yaml` as needed).  
4. Apply **Services** then **Workload** CAPA manifests (`aws_eks/clusters/services`, `.../workload`) when intentionally provisioning.  
5. Import both clusters in Rancher (optional; CAPA remains SoT for cluster objects).

## What does **not** run on management

| Workload | Why not |
|----------|---------|
| Application pods | Blast radius; capacity reserved for control plane |
| Karpenter for EKS nodes | Runs on **downstream** Services plane |
| Argo CD Principal (design) | Services plane on EKS |
| Longhorn for app storage | Prefer not on etcd nodes unless dedicated disks + design review |

## Labels

Management nodes:

```text
capacity.scke.io/reservation=reserved
capacity.scke.io/plane=management
node-role.kubernetes.io/control-plane=true   # RKE2 servers
```
