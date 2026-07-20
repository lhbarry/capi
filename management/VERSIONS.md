# Management plane — version & hardware pins

**Authority:** [ADR-001](../docs/adr/001-management-cluster-rancher.md)  
**Last verified:** 2026-07-20  

Re-verify against [Rancher](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/) and [RKE2](https://www.suse.com/suse-rke2/support-matrix/all-supported-versions/) matrices before production cutover. **Rancher Prime** is already procured — pin patches within supported Prime channels if they differ from public stable.

## Locked pins

| Component | Pin | Notes |
|-----------|-----|--------|
| **OS** | Ubuntu **24.04 LTS** (latest stable LTS track) | Policy: current LTS only; no non-LTS on mgmt |
| **AMI resolution** | SSM: `/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id` | Official Canonical; **do not hardcode** AMI long-term |
| **Example AMI** (`us-east-2`, 2026-07-20) | `ami-0dc6aa44dbcdd872e` | Snapshot only — re-resolve via SSM at deploy |
| **Instance type** | **`m7i.xlarge`** | 4 vCPU / 16 GiB; Intel; current-gen |
| **Fallback type** | `m6i.xlarge` | If `m7i` unavailable in AZ/region |
| **Root volume** | **100 GiB gp3** | Encrypted; etcd on SSD |
| **Node count** | **3** | All RKE2 **server** roles; multi-AZ |
| **RKE2** | **`v1.34.9+rke2r1`** | Aligns with downstream EKS **v1.34.x**; Ubuntu 24.04 supported on modern RKE2 (confirm matrix) |
| **Rancher Helm chart** | **`2.14.3`** | Chart repo: `https://releases.rancher.com/server-charts/stable` |
| **Rancher app version** | **`v2.14.3`** | Matches chart `appVersion` |
| **Default region (lab/prod param)** | `us-east-2` | Override per environment |

## AMI resolve command

```bash
export AWS_REGION="${AWS_REGION:-us-east-2}"
aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text
```

## Upgrade policy

| Change | Process |
|--------|---------|
| RKE2 patch (`+rke2rN`) | Test → rolling one server at a time |
| RKE2 minor | Matrix check + Ubuntu 24.04 row + Rancher support |
| Rancher patch (2.14.x) | Helm upgrade on local cluster; Prime channel preferred |
| Ubuntu next LTS | **Do not auto-adopt** until RKE2 matrix lists it |
| Instance generation (`m8i`, etc.) | Keep 4/16 shape; update type pin after validation |

## Compatibility intent

```text
Ubuntu 24.04 LTS
  └── RKE2 v1.34.9+rke2r1   (local/upstream cluster)
        └── Rancher v2.14.3
              ├── CAPI + CAPA (cluster API providers)
              └── manages → CAPA EKS v1.34.x (aws_eks/)
```
