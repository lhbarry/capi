# aws_ec2 — GitOps source of truth for AWS

This directory is the **only** place for declarative definitions of work that creates, changes, or deletes **AWS** resources for this lab.

## Project goal

Prove and document how to **create and manage a Kubernetes cluster on EC2** with:

- **CAPI** (Cluster API) + **CAPA** (Cluster API Provider AWS)
- **Full GitOps**: desired state in git → apply tracked YAML → controllers / AWS APIs reconcile

```text
GitHub (lhbarry/capi)  →  apply YAML  →  Kind (mgmt: CAPI/CAPA)  →  AWS EC2 / IAM / VPC / …
                              │
                              └── IAM CloudFormation: apply template file with AWS CLI
                                  (still from tracked YAML under aws_ec2/iam/)
```

## Hard rules

1. **No blind AWS mutations.** Do not run bootstrap CLIs that only hit the AWS API (`clusterawsadm bootstrap iam create-cloudformation-stack`, ad-hoc console clicks, one-off `aws ec2 run-instances`, etc.) as the *source* of change.
2. **YAML first.** Every AWS-facing change starts as (or is regenerated into) a file under `aws_ec2/`, reviewed, then applied **from that file**.
3. **Apply from git paths:**
   - **IAM (CloudFormation):** `aws cloudformation deploy --template-file aws_ec2/iam/...`
   - **Cluster / machines / network (CAPA CRs):** `kubectl apply -f aws_ec2/clusters/...` against Kind; CAPA reconciles to AWS.
4. **No secrets in git.** AWS keys, kubeconfigs, SSH private keys stay out of this tree (use Kind secrets / env / external secret stores).
5. **Machine process notes** stay in `local/` (gitignored). Durable procedure lives in these READMEs + YAML.

## Layout

| Path | What it owns |
|------|----------------|
| `iam/` | CAPA bootstrap IAM CloudFormation template + apply docs |
| `clusters/` | CAPI/CAPA workload cluster manifests (Cluster, AWSCluster, machines, …) |
| `providers/` | Optional: exported provider install manifests for Kind (not AWS resources) |

## Correct apply order (high level)

1. Kind management cluster exists; CAPI/CAPA controllers running (Kind-local; not AWS cluster nodes).
2. CAPA credentials Secret on Kind (from local AWS profile; not committed).
3. **Apply** `aws_ec2/iam/*.yaml` via CloudFormation **from file**.
4. **Author** CAPA/CAPI cluster YAML under `aws_ec2/clusters/`.
5. **Apply** those manifests to Kind; CAPA creates/updates EC2 and related AWS resources.
6. Change management = edit YAML → re-apply (GitOps). Never “fix in AWS and forget git”.

## Explicitly out of scope for this tree

- Kind node lifecycle (`kind create/delete`) — local Docker only.
- Installing CAPI controllers on Kind (`clusterctl init`) — management plane bootstrap; prefer documenting versions and optionally exporting provider YAML later into `providers/`. Controllers themselves are not the EC2 workload cluster.
