# Karpenter install — Workload cluster only

## Do not install on

- Management (RKE2)  
- Services EKS (`capi-eks-services`)  

## Order relative to cluster create

1. Management (Turtles/CAPI/CAPA)  
2. Services CAPA create  
3. Workload CAPA create  
4. **Then** Karpenter on Workload  

## Steps (summary)

1. Helm install Karpenter controller on **Workload** with IRSA.  
2. Tag Workload VPC subnets/SGs: `karpenter.sh/discovery=capi-eks-workload`.  
3. `kubectl apply -k aws_eks/services/karpenter/` against Workload.  
4. Confirm NodePool `reserved-workload` + overprovision pods schedule.
