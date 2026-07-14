# aws_iam — CAPA IAM CloudFormation (sole location)

**Decision:** three stacks — **common**, **ec2-self-managed**, **eks**.

This directory is the **only** place for CAPA IAM templates. Do not put IAM under `aws_ec2/` or `aws_eks/`.

Apply only via:

```bash
aws cloudformation deploy --template-file aws_iam/<file>.yaml ...
```

Do not use `clusterawsadm bootstrap iam create-cloudformation-stack` as the source of truth.

## Layout

| File | Stack name | Contents |
|------|------------|----------|
| `common.yaml` | `capa-iam-common` | Controllers role, policy, instance profile |
| `ec2-self-managed.yaml` | `capa-iam-ec2` | Control-plane + nodes (kubeadm / `aws_ec2`) |
| `eks.yaml` | `capa-iam-eks` | EKS control-plane role + controllers-eks policy |

### Cross-stack wiring

- **common** exports `capa-iam-common-ControllersPolicyArn` (and role name/ARN).  
- **ec2** imports that policy onto the control-plane role.  
- **eks** attaches controllers-eks to role name `controllers.cluster-api-provider-aws.sigs.k8s.io` (must exist from common).

## Who needs what

| Lab path | Stacks |
|----------|--------|
| Kind CAPA only | `common` |
| `aws_ec2` | `common` + `ec2` |
| `aws_eks` | `common` + `eks` |
| Both | all three |

## Deploy (`us-east-2`)

```bash
export AWS_REGION=us-east-2

aws cloudformation deploy \
  --stack-name capa-iam-common \
  --template-file aws_iam/common.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

aws cloudformation deploy \
  --stack-name capa-iam-ec2 \
  --template-file aws_iam/ec2-self-managed.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

aws cloudformation deploy \
  --stack-name capa-iam-eks \
  --template-file aws_iam/eks.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset
```

## Delete order

Path stacks first, then common:

```bash
aws cloudformation delete-stack --stack-name capa-iam-eks --region us-east-2
aws cloudformation delete-stack --stack-name capa-iam-ec2 --region us-east-2
aws cloudformation wait stack-delete-complete --stack-name capa-iam-eks --region us-east-2
aws cloudformation wait stack-delete-complete --stack-name capa-iam-ec2 --region us-east-2
aws cloudformation delete-stack --stack-name capa-iam-common --region us-east-2
```

## Upstream regenerate (optional)

```bash
clusterawsadm bootstrap iam print-cloudformation-template > /tmp/capa-iam-monolith.yaml
# re-cut into the three files above; never treat monolith create as GitOps source
```

## Related

- [`aws_ec2/`](../aws_ec2/) — self-managed CAPA clusters  
- [`aws_eks/`](../aws_eks/) — EKS CAPA clusters  
