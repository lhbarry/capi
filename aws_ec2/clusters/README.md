# Workload clusters (CAPI / CAPA) — GitOps

All **EC2 Kubernetes clusters** (and related CAPA infrastructure objects) are defined here as YAML and applied to the **Kind management cluster**. CAPA controllers reconcile those objects into AWS.

## Rules

1. Author or generate manifests into this directory **before** any apply.
2. Apply only with paths under `aws_ec2/clusters/` (or kustomize rooted here).
3. Prefer `clusterctl generate cluster ... > aws_ec2/clusters/<name>.yaml`, review, commit, then `kubectl apply -f`.
4. Updates and teardown: edit or delete YAML, re-apply / `kubectl delete -f` the same files.

## Apply

```bash
kubectl config use-context kind-capi-mgmt
kubectl apply -f aws_ec2/clusters/<name>.yaml
clusterctl describe cluster <name>
kubectl get cluster,awscluster,machine,awsmachine -A
```

## Delete

```bash
kubectl delete -f aws_ec2/clusters/<name>.yaml
# wait until AWS resources are gone before removing IAM if tearing down the lab
```

## Status

| Cluster | File | K8s | Region | Notes |
|---------|------|-----|--------|-------|
| `capi-lab-1` | `capi-lab-1.yaml` | v1.34.1 | us-east-2 | 1 CP + 1 worker, t3.large, key `Lonny_EtcConsulting` |

Flux Kustomization **`flux-system/aws-ec2-clusters`** (defined under `clusters/capi-mgmt/aws-ec2-clusters.yaml`) syncs this directory to Kind. CAPA then provisions AWS.
