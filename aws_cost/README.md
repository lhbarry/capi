# Cost guardrails (production design)

CloudFormation for a monthly **AWS Budget** alarm for the SCKE platform (WAF Cost Optimization).

## Deploy (with production environment)

Not wired to Flux:

```bash
export AWS_REGION="${AWS_REGION:-us-east-2}"

aws cloudformation deploy \
  --stack-name scke-lab-budget \
  --template-file aws_cost/production-budget.yaml \
  --parameter-overrides MonthlyBudgetAmount=50 AlertEmail=you@example.com \
  --no-fail-on-empty-changeset
```

`AlertEmail` may be omitted (empty) — budget still exists; notifications need a subscriber to page you.

## Tags

Cluster resources use `CostCenter=scke-lab` (and related tags) on CAPA objects. Budget here is account-level monthly cost unless you later add cost filters by tag.
