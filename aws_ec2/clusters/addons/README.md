# Workload cluster addons (`capi-lab-1`)

Default CAPA `clusterctl generate` does **not** ship a CNI. Without CNI (and a schedulable AWS CCM), nodes stay `NotReady` forever.

## Manifests (source of truth)

| File | Purpose |
|------|---------|
| `calico-v3.29.3.yaml` | Calico CNI (pod CIDR `192.168.0.0/16`) |
| `aws-cloud-controller-manager-ds.yaml` | AWS CCM DaemonSet with **not-ready/unreachable** tolerations |
| `kustomization.yaml` | Bundle for `kubectl apply -k` |

Also: CCM tolerations are back-ported into the CRS ConfigMap inside `../capi-lab-1.yaml` so future CRS applies match.

## Apply (workload API only)

```bash
# From management cluster context
clusterctl get kubeconfig capi-lab-1 -n default > /tmp/capi-lab-1.kubeconfig

kubectl --kubeconfig=/tmp/capi-lab-1.kubeconfig apply -k aws_ec2/clusters/addons

kubectl --kubeconfig=/tmp/capi-lab-1.kubeconfig get nodes
kubectl --kubeconfig=/tmp/capi-lab-1.kubeconfig -n kube-system get ds,pods
```

## Why not Flux → Kind?

Flux Kustomization `aws-ec2-clusters` applies `./aws_ec2/clusters` **to Kind** (CAPI/CAPA objects only — see parent `kustomization.yaml` listing `capi-lab-1.yaml`).

Calico/CCM are **workload** resources. Applying them on Kind is wrong. Options later:

1. Keep this directory + apply with workload kubeconfig (current)
2. `ClusterResourceSet` on Kind that targets the workload cluster
3. Flux `Kustomization` with a kubeconfig Secret for the workload cluster

## Order

1. CAPI/CAPA cluster objects (Flux / Kind)
2. EC2 up, apiserver reachable
3. **This kustomization** on workload (CNI + CCM)
4. Nodes Ready, Cluster Available
