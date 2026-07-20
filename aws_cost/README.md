# Cost guardrails (production design)

CloudFormation for a monthly **AWS Budget** alarm for the SCKE platform (WAF Cost Optimization).

## Deploy (with production environment)

Not wired to Flux:

```bash
export AWS_REGION="${AWS_REGION:-us-east-2}"

aws cloudformation deploy \
  --stack-name scke-production-budget \
  --template-file aws_cost/production-budget.yaml \
  --parameter-overrides MonthlyBudgetAmount=500 AlertEmail=you@example.com \
  --no-fail-on-empty-changeset
```

`AlertEmail` may be omitted (empty) — budget still exists; notifications need a subscriber to page you.

## Tags

Cluster resources use `CostCenter=scke`, `Environment=production` on CAPA/Karpenter objects. Budget is account-level monthly cost unless you later filter by tag.
