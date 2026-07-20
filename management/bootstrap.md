# Day-0 bootstrap — management RKE2 + Rancher (Ubuntu)

**Do not run against production until VPC/IAM/DNS are ready.** This is the production procedure for the **3 × m7i.xlarge** Ubuntu 24.04 plane.

Pins: [VERSIONS.md](VERSIONS.md) · CAPA placement: [capa-placement.md](capa-placement.md) · Infra: [infra/](infra/)

## Prerequisites

- [ ] AWS account + region (default `us-east-2`)  
- [ ] VPC with **3 private subnets** in **3 AZs** (and NAT or SSM endpoints for package/RKE2 pulls)  
- [ ] Ability to deploy [infra/management-cluster.yaml](infra/management-cluster.yaml)  
- [ ] DNS name for Rancher (e.g. `rancher.example.com`) → NLB  
- [ ] TLS strategy (Rancher cert-manager / public cert / private CA)  
- [ ] Rancher **Prime** registry/credentials if using Prime images  

## Phase 1 — Infrastructure (CloudFormation)

```bash
export AWS_REGION="${AWS_REGION:-us-east-2}"
export VPC_ID=vpc-...
export SUBNET_A=subnet-...   # AZ a
export SUBNET_B=subnet-...   # AZ b
export SUBNET_C=subnet-...   # AZ c

aws cloudformation deploy \
  --stack-name scke-management-rke2 \
  --template-file management/infra/management-cluster.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    VpcId="$VPC_ID" \
    SubnetIdAz1="$SUBNET_A" \
    SubnetIdAz2="$SUBNET_B" \
    SubnetIdAz3="$SUBNET_C" \
    InstanceType=m7i.xlarge \
    ProjectName=scke \
  --no-fail-on-empty-changeset
```

Outputs: instance IDs, NLB DNS, security group, instance profile.

**AMI:** template resolves Ubuntu 24.04 via SSM (see VERSIONS.md).  
**Access:** SSM Session Manager (no standing SSH required).

## Phase 2 — RKE2 HA (3 servers)

Follow [RKE2 HA](https://docs.rke2.io/install/ha) + [RKE2 for Rancher](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-cluster-setup/rke2-for-rancher).

On **node 1** (first server):

```bash
# Via SSM on instance 1
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.34.9+rke2r1" sh -
# Configure /etc/rancher/rke2/config.yaml — see rke2/config-first-server.yaml.example
systemctl enable --now rke2-server
```

Join **nodes 2 and 3** with the same token and `server: https://<node1-private-ip>:9345`.

Register **NLB** target group for API `6443` (and later Rancher `443` via ingress).

Verify:

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
# fix server URL to NLB or internal LB as designed
kubectl get nodes -o wide   # 3 Ready
```

## Phase 3 — Rancher Manager

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

kubectl create namespace cattle-system

# cert-manager if using Rancher-managed certs (version per Rancher docs for 2.14.x)
# helm install cert-manager ...

helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --version 2.14.3 \
  --set hostname=rancher.example.com \
  --set replicas=3 \
  --set bootstrapPassword=CHANGE_ME
```

For **Prime**, use Prime chart/registry instructions from SUSE (version pin still **2.14.3** line unless Prime channel dictates a patch).

## Phase 4 — CAPI / CAPA on local

See [capa-placement.md](capa-placement.md).

```bash
# Example — pin provider versions to match your clusterctl book of record
clusterctl init --infrastructure aws
# Apply CAPA IAM already from aws_iam/ if not present
# kubectl apply -f aws_eks/clusters/... when intentionally creating EKS
```

## Phase 5 — Hardening checklist

- [ ] EBS encryption on  
- [ ] SG: only required RKE2/Rancher ports; no 0.0.0.0/0 to 6443 from internet unless intended  
- [ ] SSM only; disable password SSH  
- [ ] etcd snapshots scheduled  
- [ ] Rancher backup configured  
- [ ] Labels `capacity.scke.io/*` applied  
- [ ] Ubuntu unattended-upgrades + reboot window for 1/3 nodes  

## Teardown (non-prod)

Delete CAPA downstream clusters first → uninstall Rancher → stop RKE2 → delete CFN stack.
