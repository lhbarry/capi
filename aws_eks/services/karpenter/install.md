# Install Karpenter controller (when leaving pure-dev)

Controller is **not** vendored as raw YAML here (version churn). Use official Helm + IRSA.

## Outline

1. Create Karpenter controller IAM role (IRSA) trusted by cluster OIDC.  
2. Install CRDs + chart into `kube-system` (recommended) or `karpenter`.  
3. Set `settings.clusterName=capi-eks-1`, `settings.interruptionQueue` if using SQS.  
4. Apply this kustomize package (`NodePool` / `EC2NodeClass` / overprovisioning).

Pin chart version in your install runbook when first applied; record it in git.

```bash
# Example shape only — pin versions and account IDs before use
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace kube-system \
  --set "settings.clusterName=capi-eks-1" \
  --set "settings.defaultNodeClass=default" \
  # --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=...
```

IAM for nodes: Karpenter typically uses its own node role; align `EC2NodeClass.spec.role` with that role name (see `nodeclass-default.yaml`).
