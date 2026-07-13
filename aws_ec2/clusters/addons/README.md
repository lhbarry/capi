# Workload cluster addons (capi-lab-1)

Default CAPA `clusterctl generate` templates do **not** install a CNI. Nodes stay `NotReady` (`cni plugin not initialized`) until one is applied.

## Calico

- File: `calico-v3.29.3.yaml` (upstream projectcalico v3.29.3)
- Matches default pod CIDR `192.168.0.0/16` in the CAPA Cluster template
- Applied to the **workload** cluster (not Kind)

Flux currently syncs `aws_ec2/clusters` to Kind (CAPI objects). Calico must be applied **to the workload** API (kubeconfig from `clusterctl get kubeconfig`), or via a ClusterResourceSet / HelmRelease targeting the remote cluster later.

## AWS CCM note

CRS installs `aws-cloud-controller-manager`, but the stock DaemonSet may not tolerate `node.kubernetes.io/not-ready`, so Desired=0 while CNI is missing. After CNI (or after adding not-ready tolerations), CCM schedules and sets ProviderID / InternalIP.
