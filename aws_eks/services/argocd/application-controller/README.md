# ApplicationController (Services cluster)

Argo CD **application-controller** on the **Services** cluster (with Principal).

## Why ApplicationController (not ApplicationSetController)

Platform rule: the Principal install uses **ApplicationController** for Services apps. **ApplicationSetController is disabled** on Principal. Services desired state is expressed as **Application** CRs (including root/app-of-apps **Application** objects if needed), not ApplicationSets on this hub.

## Responsibility

- Reconcile **Application** CRs that target the **Services** plane.  
- Co-located with Principal (same cluster; required).  
- Does **not** replace the Workload **Agent**.  
- Does **not** co-exist with an Agent on this cluster.

## Why separate values file

Allows scaling and resource limits for the controller independently of API/UI in the Helm merge:

```bash
helm upgrade --install argocd argo/argo-cd ... \
  -f principal/values-principal.yaml \
  -f application-controller/values-application-controller.yaml
```

## Placement

Same Services node pool / taints as Principal.
