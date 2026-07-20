# Capacity model — production Reserved nodes + Karpenter headroom

## Goals (production / WAF)

1. **Reserved** baseline capacity for three domains (Reliability + Operational Excellence).  
2. **Karpenter** on the **Services plane** scales EC2 so platform and apps land without cold start.  
3. Keep **≥ 1.5 × one worker node** of CPU **and** memory **available and waiting** (preemptible headroom — Performance + Reliability under burst).

This is the **production capacity floor**, not a lab experiment. Cost is governed with tags, budgets, and elastic consolidation — not by collapsing Reserved floors.

## Reference worker

| Field | Value | Source |
|-------|-------|--------|
| Instance | `t3.large` | Bootstrap `AWSMachineTemplate` + NodePool family |
| vCPU | 2 | AWS instance shape |
| Memory | 8 GiB | AWS instance shape |
| **1.5 × worker headroom** | **3 vCPU + 12 GiB** | Waiting capacity |

## Reservations

| Domain | Count | Label / taint plane | Status |
|--------|------:|---------------------|--------|
| Management cluster | **3** | `capacity.scke.io/plane=management` | **Reserved** — management host TBD; fixed capacity |
| Services plane | **5** | `capacity.scke.io/plane=services` | **Reserved** — NodePool `reserved-services` |
| Workload plane | **5** | `capacity.scke.io/plane=workload` | **Reserved** — NodePool `reserved-workload` |

```text
capacity.scke.io/reservation=reserved
```

### Management (3 Reserved)

- Separate **management cluster** (host product still TBD).  
- Target: **3** multi-AZ nodes for CAPI/CAPA/GitOps control plane.  
- See `management-reserved.md`. **Not** scaled by Services-plane Karpenter.

### Services & Workload (5 + 5 Reserved)

On the EKS cluster that hosts Services + Workload:

1. Karpenter **NodePools** with labels/taints per plane.  
2. **Overprovisioning** Deployments: low priority, ~one worker resources each, hostname anti-affinity, `replicas: 5` → holds **5 nodes** per plane.  
3. Real pods use higher priority + plane tolerations; they preempt pause pods; Karpenter + headroom absorb the shock.

NodePool `limits` cap each reserved pool (~5 × t3.large).

### Headroom (1.5 × worker, waiting)

`headroom-overprovision` requests **3 CPU + 12 GiB** on the **elastic** pool (lowest priority).

- Idle: capacity is **available and waiting**.  
- Burst: preempt → schedule real work → Karpenter scales → headroom refills.

## Bootstrap vs Karpenter

| Layer | Role | Production |
|-------|------|------------|
| CAPA `MachineDeployment` | Bootstrap / system | **2** replicas multi-AZ (HA for Karpenter, CoreDNS, CNI) |
| Karpenter | Reserved + elastic | **5 + 5 Reserved** + **1.5×** headroom + burst |

Do not treat Reserved pause capacity as “waste” to consolidate away; reserved pools use conservative disruption.

## Cost governance (production)

Full floor ≈ **3 (mgmt) + 2 (bootstrap) + 5 (services) + 5 (workload) + headroom (~1–2)** nodes.

- Tags: `Project`, `Environment=production`, `CostCenter=scke`  
- Budgets: `aws_cost/`  
- Consolidate **elastic** aggressively; **Reserved** slowly / when empty only  
