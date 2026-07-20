# EKS secrets CMK (production design)

CloudFormation for a customer-managed KMS key used by CAPA:

```yaml
encryptionConfig:
  provider: alias/cluster-api-provider-aws-eks-secrets
  resources: [secrets]
```

## Deploy (production environment)

Not wired to Flux. Apply with AWS CLI before cluster create:

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
- Key rotation enabled; pending window on delete is short for operational flexibility — tighten for long-lived prod keys if policy requires.
