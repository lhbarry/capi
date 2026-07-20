# Management cluster infrastructure (CloudFormation)

Template: [`management-cluster.yaml`](management-cluster.yaml)

| Creates | Does not create |
|---------|-----------------|
| 3× EC2 (`m7i.xlarge` default), Ubuntu 24.04 via SSM AMI | RKE2 install |
| 100 GiB encrypted gp3 roots | Rancher install |
| Instance profile + SSM | VPC / subnets |
| SGs + internal NLB (6443, 443) | CAPA IAM (see `aws_iam/`) |

## Deploy

Requires existing VPC + 3 private subnets (one per AZ). See [../bootstrap.md](../bootstrap.md).

```bash
aws cloudformation deploy \
  --stack-name scke-management-rke2 \
  --template-file management/infra/management-cluster.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    VpcId=vpc-xxx \
    SubnetIdAz1=subnet-a \
    SubnetIdAz2=subnet-b \
    SubnetIdAz3=subnet-c \
    InstanceType=m7i.xlarge
```

## CAPA IAM on management nodes

Default instance role includes **SSM only**. Attach CAPA controller policies (or instance profile from `aws_iam/common.yaml` pattern) before running CAPA, or use IRSA after OIDC is available on RKE2. See [../capa-placement.md](../capa-placement.md).
