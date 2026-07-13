# Kind management cluster (`capi-mgmt`) — Flux GitOps

Flux bootstrapped against `lhbarry/capi` with path `./clusters/capi-mgmt`.

## Layout

| Path | Purpose |
|------|---------|
| `flux-system/` | Flux controllers + GitRepository/Kustomization sync (bootstrap; do not hand-edit lightly) |
| `weave-gitops-dashboard.yaml` | Weave GitOps UI (HelmRepository + HelmRelease) |
| `kustomization.yaml` | Root kustomize entry for this path |

## Weave GitOps UI (lab)

| Field | Value |
|-------|--------|
| Username | `admin` |
| Password | Lab default set at install — see `local/Process.md` (not committed) |
| Access | `kubectl -n flux-system port-forward svc/ww-gitops-weave-gitops 9001:9001` → http://127.0.0.1:9001 |

Password is a **bcrypt hash** in the HelmRelease values. Rotate for anything beyond laptop lab.

## CAPA / AWS GitOps

Workload CAPA YAML stays under `aws_ec2/`. Point a separate Flux `Kustomization` at `aws_ec2/clusters` when ready (Phase 3). Do not mix IAM CloudFormation apply into this path without a deliberate design.
