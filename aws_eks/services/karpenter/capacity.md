# Capacity model — Reserved nodes + Karpenter headroom

## Goals

1. **Reserved** baseline capacity for three domains (not free-for-all consolidation).  
2. **Karpenter** on the **Services plane** scales EC2 so real workloads can land without waiting cold.  
3. Keep **≥ 1.5 × one worker node** of CPU **and** memory **available and waiting** (preemptible headroom).

## Reference worker

| Field | Value | Source |
|-------|-------|--------|
| Instance | `t3.large` | `aws_eks/clusters/capi-eks-1.yaml` AWSMachineTemplate |
| vCPU | 2 | AWS instance shape |
| Memory | 8 GiB | AWS instance shape |
| **1.5 × worker headroom** | **3 vCPU + 12 GiB** | This model |

Headroom uses **instance-shape** requests (not kube-reserved allocatable). Slight over-ask is intentional so Karpenter keeps a full extra node class ready under load.

## Reservations

| Domain | Count | Label / taint plane | Status |
|--------|------:|---------------------|--------|
| Management cluster | **3** | `capacity.scke.io/plane=management` | **Reserved** — management host (TBD); not Karpenter on workload EKS |
| Services plane | **5** | `capacity.scke.io/plane=services` | **Reserved** — Karpenter NodePool `reserved-services` |
| Workload plane | **5** | `capacity.scke.io/plane=workload` | **Reserved** — Karpenter NodePool `reserved-workload` |

Common reservation label on reserved nodes:

```text
capacity.scke.io/reservation=reserved
```

### Management (3 Reserved)

- Applies to the **management cluster** once chosen (not Kind-as-architecture).  
- Target: **3** nodes marked Reserved for CAPI/CAPA/Flux (or successor) control plane.  
- Implementation when mgmt is CAPA/EKS: fixed MachineDeployment `replicas: 3` + labels above (see `management-reserved.md`).  
- **Not** scaled by the Services-plane Karpenter instance (different cluster).

### Services & Workload (5 + 5 Reserved)

On the **Services Cluster** (EKS that hosts Services + Workload planes):

1. Karpenter **NodePools** `reserved-services` and `reserved-workload` with matching labels/taints.  
2. **Overprovisioning** Deployments (`overprovisioning/`) with:
   - low `PriorityClass` (preemptible),
   - resource requests ≈ one `t3.large` each,
   - required pod anti-affinity on hostname → **one pause pod per node**,
   - `replicas: 5` per plane → **minimum 5 nodes** per pool while pause pods exist.  
3. Real Services/Workload pods use higher priority + plane nodeSelector/tolerations; they **preempt** pause pods; Karpenter replaces capacity via headroom + pending demand.

NodePool `limits` cap each reserved pool (cpu/memory sized for ~5 × t3.large) so reservations do not unbounded-grow.

### Headroom (1.5 × worker, waiting)

Deployment `headroom-overprovision` requests **3 CPU + 12 GiB** total (single pod or equivalent), lowest priority, scheduled on the **elastic** NodePool (or any schedulable Karpenter node without exclusive taints).

- While idle: that capacity sits **available and waiting**.  
- When burst demand arrives: headroom pods are preempted; real pods schedule; Karpenter scales out; headroom pods reschedule → refill buffer.

## Bootstrap vs Karpenter

| Layer | Role |
|-------|------|
| CAPA `MachineDeployment` | Bootstrap / system (run Karpenter controller, CoreDNS, etc.). Lab may stay `replicas: 1+`. |
| Karpenter | Reserved Services/Workload pools + elastic headroom and burst |

Do not consolidate away Reserved pause-backed capacity aggressively; reserved NodePools use longer `consolidateAfter` and do-not-disrupt where needed.

## Cost note (lab)

Full reserved floor ≈ **3 (mgmt) + 5 (services) + 5 (workload) + headroom (~1–2)** nodes plus bootstrap — **not** the old 1-worker lab floor. Use only when intentionally leaving pure-dev; keep manifests unapplied under Flux until then.
