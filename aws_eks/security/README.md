# Kubernetes security baselines (EKS)

| Manifest | Target cluster |
|----------|----------------|
| `namespaces-pss.yaml` | Services + Workload (create ns as needed) |
| `networkpolicy-argocd-services.yaml` | **Services only** (`argocd` ns) |

```bash
# Services
kubectl --context services apply -f namespaces-pss.yaml
kubectl --context services apply -f networkpolicy-argocd-services.yaml

# Workload
kubectl --context workload apply -f namespaces-pss.yaml
# Agent namespace included; add workload app NetworkPolicies per AppProject later
```

Complements account-level [`aws_security/`](../../aws_security/) detection stack.
