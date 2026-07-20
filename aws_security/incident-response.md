# Incident response — design stub (SEC)

Lightweight IR process for production. Expand with contacts and tooling as you go live.

## Prepare

| Asset | Location |
|-------|----------|
| CloudTrail | `aws_security/detection.yaml` → **S3** (CMK) |
| GuardDuty | Same stack |
| EKS CP / app logs | CAPA CP logging → CW (AWS sink) → **Loki**; apps → **Loki** via OTel/Fluent Bit |
| Metrics / alerts | **Mimir + Grafana** alert rules (`aws_eks/services/lgtm/alerts/`) |
| Cluster snapshots | Velero + EKS managed etcd |

## Detect

1. GuardDuty findings (15 min publishing).  
2. **Grafana / Alertmanager** (LGTM rules — node NotReady, CPU, crashloop).  
3. Loki queries on EKS audit (after CW→Loki bridge) + Argo anomalies.

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
