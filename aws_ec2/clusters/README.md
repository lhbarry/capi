# EC2 workload clusters (CAPA self-managed)

## GitOps only

Applied by Flux Kustomization **`flux-system/aws-ec2-clusters`** → Kind → CAPA → AWS.

```bash
# 1) Set params in kustomization.yaml (configMapGenerator literals)
# 2) Enable: resources: [capi-lab-1.yaml]
# 3) git commit && git push
```

## Parameters (`kustomization.yaml`)

| Literal | Purpose |
|---------|---------|
| `AWS_REGION` | AWS region for `AWSCluster` |
| `AWS_SSH_KEY_NAME` | Existing EC2 key pair name (not a private key) |

Cluster YAML uses placeholders (`PLACEHOLDER_*`); **replacements** inject values from the generated ConfigMap.

## Clusters

| File | Notes |
|------|-------|
| `capi-lab-1.yaml` | kubeadm, v1.34.1, 1 AZ / 1 NAT when enabled |

## Addons

`addons/` — Calico + CCM for the **workload** API after the cluster is up.
