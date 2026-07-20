# AWS service quotas — watchlist (REL)

Track and request increases **before** scale events.

| Service | Quota | Why |
|---------|-------|-----|
| EC2 | Running On-Demand Standard instances | Services 5 + Workload bootstrap/Karpenter + Management 3 |
| EC2 | EIPs / NAT Gateways per AZ | 3 AZ × 2 clusters (if separate VPCs) |
| EKS | Clusters per region | Minimum **2** (services + workload) + future |
| EKS | Nodes per cluster | Workload Karpenter growth |
| VPC | VPCs per region | Management + EKS VPCs if split |
| ELB | Network Load Balancers | Management NLB + future |
| IAM | Roles per account | IRSA proliferation |
| EBS | Storage / snapshots | Velero volume snapshots |

## Process

1. Baseline current quotas in each region (`Service Quotas` console or CLI).  
2. Document soft limits for lab vs production accounts.  
3. Open increase tickets when >60% of limit sustained.  
