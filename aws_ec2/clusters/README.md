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
| `capi-lab-1` | `capi-lab-1.yaml` | v1.34.1 | us-east-2 | 1 CP + 1 worker, t3.large, key `Lonny_EtcConsulting`, **1 AZ / 1 NAT** (`availabilityZoneUsageLimit: 1`) |

Flux Kustomization **`flux-system/aws-ec2-clusters`** (defined under `clusters/capi-mgmt/aws-ec2-clusters.yaml`) syncs this directory to Kind. CAPA then provisions AWS.

## Network / NAT (lab)

Default CAPA managed VPC uses **3 AZs → 3 NAT Gateways** (expensive). This lab pins:

```yaml
# AWSCluster.spec.network.vpc
availabilityZoneUsageLimit: 1
availabilityZoneSelection: Ordered   # first AZ alphabetically in the region
```

That yields **1 public + 1 private subnet and a single NAT**. Changing this on an existing cluster does **not** shrink an already-provisioned VPC; recreate the cluster (delete `Cluster`, wait for AWS teardown, re-apply) to pick up a new layout.

## Workload addons (CNI / CCM)

After the CAPA cluster objects are reconciled and the API is up:

```bash
clusterctl get kubeconfig capi-lab-1 -n default > /tmp/capi-lab-1.kubeconfig
kubectl --kubeconfig=/tmp/capi-lab-1.kubeconfig apply -k aws_ec2/clusters/addons
```

See `addons/README.md`. Parent `kustomization.yaml` stays CAPI-only (Flux → Kind).
