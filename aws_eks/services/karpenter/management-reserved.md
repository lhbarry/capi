# Management cluster — 3 nodes Reserved

| Field | Value |
|-------|--------|
| Domain | Management plane |
| Reservation | **3 nodes Reserved** |
| Software | **SUSE Rancher** on **RKE2** (3 server nodes; **Prime** in place) |
| **OS** | **Ubuntu latest stable** (LTS track; currently 24.04 LTS) |
| **AMI** | Official Canonical Ubuntu Server |
| **Node shape** | **4 vCPU / 16 GiB RAM / 100 GiB gp3 SSD** |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` |
| Labels | `capacity.scke.io/reservation=reserved`, `capacity.scke.io/plane=management` |
| Scaler | Fixed 3; not Services-plane Karpenter |
| Decision | [ADR-001](../../../docs/adr/001-management-cluster-rancher.md) |
| Design tree | [`management/`](../../../management/) |

## AMI (AWS)

**Locked family:** Ubuntu latest stable LTS — **Canonical official AMI** only.  
Confirm RKE2 support matrix for that LTS at version pin.  
**Not** SLE Micro / SLES for this design.

## Sizing

**Locked:** **4 / 16 / 100 gp3** × **3** multi-AZ.

## Relation to Kind lab

`clusters/capi-mgmt` is **not** this plane.
