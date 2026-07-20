# Management cluster — 3 nodes Reserved

| Field | Value |
|-------|--------|
| Domain | Management plane |
| Reservation | **3 nodes Reserved** |
| Software | **SUSE Rancher** on **RKE2** (3 server nodes) |
| **Node shape** | **4 vCPU / 16 GiB RAM / 100 GiB gp3 SSD** |
| Instance examples | `m7i.xlarge`, `m6i.xlarge`, `m5.xlarge` |
| Labels | `capacity.scke.io/reservation=reserved`, `capacity.scke.io/plane=management` |
| Scaler | Fixed 3; not Services-plane Karpenter |
| Decision | [ADR-001](../../../docs/adr/001-management-cluster-rancher.md) |
| Design tree | [`management/`](../../../management/) |

## AMI (AWS)

**Preferred:** **SLE Micro** AMI (SUSE Marketplace / public cloud).  
**Alts:** SLES 15 SP; Ubuntu 24.04 if matrix-certified for pinned RKE2; else Ubuntu 22.04.  
**Avoid:** Amazon Linux as primary.

Confirm OS against RKE2 support matrix for the pinned RKE2 version before locking AMI ID.

## Sizing

**Locked:** **4 / 16 / 100 gp3** × **3** multi-AZ (Rancher Small RKE2 upstream floor).

## Relation to Kind lab

`clusters/capi-mgmt` is **not** this plane.
