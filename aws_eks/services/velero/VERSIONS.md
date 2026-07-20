# Velero pins

| Component | Pin (verify at install) |
|-----------|-------------------------|
| Velero | **v1.15.x** (or current stable supported with EKS 1.34) |
| Helm chart | `vmware-tanzu/velero` matching app version |
| AWS plugin | **velero-plugin-for-aws** v1.11.x+ |

```bash
helm search repo vmware-tanzu/velero --versions | head
```
