# IAM bootstrap (CAPA) — GitOps

CAPA needs IAM roles, policies, and instance profiles in the AWS account. Those resources are defined **only** by the CloudFormation template in this directory.

## Files

| File | Purpose |
|------|---------|
| `cluster-api-provider-aws-sigs-k8s-io.yaml` | CloudFormation template (desired IAM state) |
| `README.md` | Apply / delete procedure |

Stack name (fixed by CAPA convention): **`cluster-api-provider-aws-sigs-k8s-io`**  
Region for CLI: **`us-east-2`** (IAM is global; use a consistent region for the stack API).

## Generate / refresh template (does not apply)

When upgrading `clusterawsadm` / CAPA, regenerate the template **into git**, review the diff, then apply:

```bash
export AWS_REGION=us-east-2
clusterawsadm bootstrap iam print-cloudformation-template \
  > aws_ec2/iam/cluster-api-provider-aws-sigs-k8s-io.yaml
# commit the diff, then deploy (below)
```

**Forbidden as the change source:**  
`clusterawsadm bootstrap iam create-cloudformation-stack`  
(that mutates AWS without going through this file as the apply artifact).

## Apply (from YAML only)

```bash
export AWS_REGION=us-east-2

aws cloudformation deploy \
  --stack-name cluster-api-provider-aws-sigs-k8s-io \
  --template-file aws_ec2/iam/cluster-api-provider-aws-sigs-k8s-io.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

aws cloudformation describe-stacks \
  --stack-name cluster-api-provider-aws-sigs-k8s-io \
  --query 'Stacks[0].{Status:StackStatus,Name:StackName}' \
  --output table
```

## Delete (from known stack; template remains in git)

```bash
export AWS_REGION=us-east-2
aws cloudformation delete-stack --stack-name cluster-api-provider-aws-sigs-k8s-io
aws cloudformation wait stack-delete-complete --stack-name cluster-api-provider-aws-sigs-k8s-io
```

## Resources defined by the template

- Roles: control-plane, controllers, nodes, eks-controlplane  
- Managed policies: control-plane, nodes, controllers, controllers-eks  
- Instance profiles: control-plane, controllers, nodes  

## Related (not in this template)

| Item | Notes |
|------|--------|
| EC2 SSH key | Existing lab key `Lonny_EtcConsulting` in `us-east-2` — referenced by cluster YAML as `AWS_SSH_KEY_NAME`, not created here |
| CAPA credentials Secret | Lives on Kind only (`capa-manager-bootstrap-credentials`); never commit |

## Correction history

| Date | Event |
|------|--------|
| 2026-07-13 | First create used `create-cloudformation-stack` (imperative). Stack deleted. Re-applied with `aws cloudformation deploy --template-file` from this YAML. |
