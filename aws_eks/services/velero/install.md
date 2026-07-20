# Velero install

## Order

1. Create S3 bucket + KMS (or reuse platform bucket with prefix).  
2. Deploy IRSA roles for Velero on Services and Workload (OIDC).  
3. Helm install Velero on **Services**, then **Workload**.  
4. Apply BSL + Schedules per cluster.  
5. Run first [restore drill](restore-drill.md) in non-prod.

## Helm sketch

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  -f aws_eks/services/velero/values-example.yaml \
  --set configuration.backupStorageLocation[0].bucket=BUCKET \
  --set configuration.backupStorageLocation[0].config.region=us-east-2 \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT:role/scke-velero
```

Apply schedules:

```bash
kubectl --context services apply -f backupstoragelocation.yaml -f schedules-services.yaml
kubectl --context workload apply -f backupstoragelocation.yaml -f schedules-workload.yaml
```
