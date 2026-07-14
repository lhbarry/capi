# EC2 workload clusters (CAPA self-managed)

## GitOps only

Applied by Flux Kustomization **`flux-system/aws-ec2-clusters`** → Kind → CAPA → AWS.

```bash
# Correct
git add aws_ec2/clusters && git commit && git push

# Wrong
kubectl apply -f aws_ec2/clusters/...
```

Job definition (also in git): `clusters/capi-mgmt/jobs/aws-ec2-clusters.yaml`.

## Clusters

| Name | File | Notes |
|------|------|-------|
| `capi-lab-1` | `capi-lab-1.yaml` | kubeadm, v1.34.1, 1 CP + 1 worker, 1 AZ / 1 NAT |

Job is **suspended** by default (`spec.suspend: true`) so teardown stays down. To provision: set `suspend: false` in the job YAML, commit, push.

## Addons

`addons/` — Calico + CCM; apply to **workload** API after cluster up (or extend GitOps later). Not applied by the Kind Flux job (CAPI objects only).
