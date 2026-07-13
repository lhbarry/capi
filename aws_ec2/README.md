# aws_ec2

Git-tracked resources that support **AWS** for this lab: CAPA/CAPI cluster definitions, IAM notes (no secrets), network helpers, and related manifests.

## Role in the flow

```text
GitHub (this repo)  →  GitOps on Kind (mgmt)  →  AWS managed/workload cluster (CAPA)
```

Anything applied to provision or configure AWS infrastructure for the workload cluster lives under this directory (or is generated here and committed after scrubbing secrets).

## Conventions

- **No secrets** in git (AWS keys, kubeconfigs, SSH private keys, bootstrap passwords).
- Prefer declarative YAML under this tree; reference paths from GitOps tooling on Kind.
- Generated cluster manifests go here (e.g. `aws_ec2/clusters/<name>.yaml`) after redaction if needed.
- Machine-local process notes stay in `local/` (gitignored).

## Layout (evolving)

| Path | Purpose |
|------|---------|
| `README.md` | This file |
| `clusters/` | CAPA/CAPI `Cluster` manifests (planned) |
| `providers/` | CAPA/CAPI provider config applied via GitOps (planned) |
| `iam/` | Non-secret IAM/bootstrap docs or CFN templates (planned) |
