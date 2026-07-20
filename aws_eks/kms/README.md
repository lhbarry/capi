# EKS secrets CMK (lab)

CloudFormation for a customer-managed KMS key used by CAPA:

```yaml
encryptionConfig:
  provider: alias/cluster-api-provider-aws-eks-secrets
  resources: [secrets]
```

## Deploy (only when leaving pure-dev / ready for AWS)

Not wired to Flux. Apply with AWS CLI when you intentionally create cloud resources:

```bash
export AWS_REGION="${AWS_REGION:-us-east-2}"

aws cloudformation deploy \
  --stack-name capa-eks-secrets-cmk \
  --template-file aws_eks/kms/eks-secrets-cmk.yaml \
  --no-fail-on-empty-changeset
```

**Order:** IAM stacks → this CMK → enable CAPA cluster manifests.

## Notes

- Alias prefix `cluster-api-provider-aws-*` matches `aws_iam/eks.yaml` KMS grant conditions.
- Key rotation enabled; 7-day pending window on delete (lab-friendly).
- Do not deploy from a “no AWS yet” session.
