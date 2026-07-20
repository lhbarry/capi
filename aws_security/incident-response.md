# Incident response — design stub (SEC)

Lightweight IR process for production. Expand with contacts and tooling as you go live.

## Prepare

| Asset | Location |
|-------|----------|
| CloudTrail | `aws_security/detection.yaml` → S3 + CWL |
| GuardDuty | Same stack |
| EKS audit logs | CAPA `logging` all five → CloudWatch |
| Cluster snapshots | Velero (design next) + EKS etcd (managed) |

## Detect

1. GuardDuty findings (15 min publishing).  
2. CloudTrail / CloudWatch metric filters (add alarms in follow-on).  
3. Argo / Kubernetes audit anomalies.

## Respond (first hour)

1. **Contain** — revoke IRSA/session, isolate SG, disable public access (already private API).  
2. **Preserve** — do not delete CloudTrail/S3; snapshot volumes if EC2 involved.  
3. **Scope** — which cluster (mgmt / services / workload)? CAPA vs app path?  
4. **Eradicate / recover** — redeploy from git (immutable desired state); rotate secrets (OpenBao/ESO).  
5. **Post-incident** — update this runbook; file finding in wa-scorecard.

## Contacts

| Role | Contact |
|------|---------|
| Platform on-call | TBD |
| Security | TBD |
| AWS support / Prime | Rancher Prime + AWS Business/Enterprise TBD |
