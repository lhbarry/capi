# Kind management cluster (`capi-mgmt`) — Flux GitOps

Flux bootstrapped against `lhbarry/capi` path `./clusters/capi-mgmt`.

## Layout

| Path | Purpose |
|------|---------|
| `flux-system/` | Flux controllers + GitRepository/Kustomization sync (bootstrap) |
| `weave-gitops-dashboard.yaml` | Weave GitOps UI HelmRelease |
| `jobs/aws-ec2-clusters.yaml` | **Flux job** → `./aws_ec2/clusters` (self-managed CAPA) |
| `jobs/aws-eks-clusters.yaml` | **Flux job** → `./aws_eks/clusters` (EKS CAPA) |
| `kustomization.yaml` | Root kustomize entry for this path |

## Two provisioning jobs

| Job name | Suspend default | Git path | Provisions |
|----------|-----------------|----------|------------|
| `aws-ec2-clusters` | `true` (safe after teardown) | `aws_ec2/clusters` | EC2 kubeadm CAPA |
| `aws-eks-clusters` | `false` | `aws_eks/clusters` | EKS CAPA |

Change suspend or cluster YAML **in git**, push — never `kubectl apply` the workload CRs by hand.

## Weave GitOps UI (lab)

```bash
kubectl -n flux-system port-forward svc/ww-gitops-weave-gitops 9001:9001
```

Username `admin`; password is the bcrypt in the HelmRelease (local lab secret).
