# Capacity model — three clusters

## Floors

| Domain | Count | Mechanism |
|--------|------:|-----------|
| **Management** | **3** Reserved | RKE2 servers (`m7i.xlarge` 4/16/100 gp3) |
| **Services** | **5** Reserved | CAPA `MachineDeployment` replicas: **5** — **no Karpenter** |
| **Workload** | **5** Reserved + **≥1.5× worker** headroom | CAPA bootstrap **2** + **Karpenter** only |

Reference worker for Workload Karpenter math: **t3.large** (2 vCPU / 8 GiB) → headroom **3 vCPU / 12 GiB**.

## Karpenter scope

**Workload cluster only.** Services does not run Karpenter.

## Workload Karpenter detail

- NodePool `reserved-workload` + 5× pause overprovision  
- NodePool `elastic` + headroom pause (1.5× worker)  
- Discovery: `capi-eks-workload`  
