# Restore drill (quarterly minimum)

**REL requirement:** prove restore path; update date log below after each drill.

## Objectives

| Metric | Target |
|--------|--------|
| RPO demonstrated | ≤ 24 h (last successful backup) |
| RTO demonstrated | ≤ 4 h for a single namespace restore |

## Preconditions

- [ ] Velero Schedules `Completed` backups in last 24 h  
- [ ] Non-production namespace or dedicated drill ns available  
- [ ] Change window approved  

## Procedure (namespace restore)

1. Pick cluster: **Services** or **Workload**.  
2. List backups: `velero backup get`  
3. Create drill namespace (or restore into renamed ns):

```bash
velero restore create drill-$(date +%Y%m%d) \
  --from-backup <BACKUP_NAME> \
  --include-namespaces <NS> \
  --namespace-mappings <NS>:drill-<NS>
```

4. Validate: pods Ready, PVCs bound, Argo Application Healthy (if applicable).  
5. Tear down drill namespace.  
6. Record results.

## Full cluster loss (tabletop / rare)

1. Recreate cluster via CAPA from git (Management).  
2. Reinstall Velero + BSL.  
3. Restore critical namespaces from S3.  
4. Re-register Argo Agent (Workload) to Principal.  

## Drill log

| Date | Cluster | Backup | Result | RTO | Notes |
|------|---------|--------|--------|-----|-------|
| _TBD_ | | | | | First drill after go-live |
