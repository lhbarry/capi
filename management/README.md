# Management plane — SUSE Rancher (production)

**Decision:** [docs/adr/001-management-cluster-rancher.md](../docs/adr/001-management-cluster-rancher.md)  
**Pins:** [VERSIONS.md](VERSIONS.md) · **Bootstrap:** [bootstrap.md](bootstrap.md) · **CAPI/CAPA:** [capa-placement.md](capa-placement.md)

| Item | Value |
|------|--------|
| Software | **SUSE Rancher** **v2.14.3** on **RKE2** **v1.34.9+rke2r1** (Prime in place) |
| Nodes | **3** RKE2 servers, multi-AZ |
| **OS** | **Ubuntu 24.04 LTS** (latest stable LTS track) |
| **AMI** | Canonical via SSM (see VERSIONS.md); e.g. `us-east-2` snapshot `ami-0dc6aa44dbcdd872e` |
| **Instance** | **`m7i.xlarge`** (fallback `m6i.xlarge`) |
| **Shape** | **4 vCPU / 16 GiB / 100 GiB gp3** |
| Labels | `capacity.scke.io/reservation=reserved`, `plane=management` |

## Layout

| Path | Purpose |
|------|---------|
| [VERSIONS.md](VERSIONS.md) | Locked versions, AMI SSM path, instance type |
| [bootstrap.md](bootstrap.md) | Day-0 procedure (infra → RKE2 → Rancher → CAPA) |
| [capa-placement.md](capa-placement.md) | CAPI/CAPA on local cluster vs downstream EKS |
| [infra/](infra/) | CloudFormation for 3 nodes + NLB + SSM |
| [rke2/](rke2/) | config.yaml examples |
| [rancher/](rancher/) | Helm values sketch |

## Quick path

1. Deploy `infra/management-cluster.yaml` into a 3-AZ VPC.  
2. Install RKE2 HA with pin `v1.34.9+rke2r1` ([bootstrap.md](bootstrap.md)).  
3. Helm install Rancher chart `2.14.3`.  
4. `clusterctl init --infrastructure aws` on local; apply `aws_eks/` when ready.  

**Not Flux-wired.** Experimental Kind path: `clusters/capi-mgmt/` (historical).
