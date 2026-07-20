# Management cluster — 3 nodes Reserved

| Field | Value |
|-------|--------|
| Domain | Management plane |
| Reservation | **3 nodes Reserved** |
| Labels | `capacity.scke.io/reservation=reserved`, `capacity.scke.io/plane=management` |
| Scaler | **Not** Services-plane Karpenter (separate cluster) |

## When management host is CAPA → EKS (or kubeadm)

Pin a MachineDeployment (or managed node group) at **`replicas: 3`** with the labels above. Prefer multi-AZ spread.

Example shape (apply only when management product is decided — **not** wired today):

```yaml
# Illustrative — do not apply to workload capi-eks-1
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: mgmt-reserved
  labels:
    capacity.scke.io/reservation: reserved
    capacity.scke.io/plane: management
spec:
  replicas: 3
  # ... clusterName, bootstrap, infrastructureRef for the chosen management cluster
```

## Today

Experimental Kind `capi-mgmt` is **not** the production management plane and does **not** satisfy the 3-node Reserved target. Choose a production management host and implement **3 Reserved** multi-AZ nodes with the labels above ([ARCHITECTURE.md](../../../ARCHITECTURE.md) §1 / §8).
