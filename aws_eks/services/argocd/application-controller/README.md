# ApplicationController (Services cluster)

Argo CD **application-controller** on the **Services** cluster.

## Responsibility

- Reconcile **Application** / **ApplicationSet** resources that target the **Services** plane (platform components, Principal-adjacent apps).  
- Co-located with Principal (same Argo CD install / same API).  
- Does **not** replace the Workload **Agent** for workload-plane apply.

## Why separate values file

Allows scaling and resource limits for the controller independently of API/UI in the Helm merge:

```bash
helm upgrade --install argocd argo/argo-cd ... \
  -f principal/values-principal.yaml \
  -f application-controller/values-application-controller.yaml
```

## Placement

Same Services node pool / taints as Principal.
