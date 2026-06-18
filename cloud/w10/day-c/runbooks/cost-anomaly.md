# Runbook - Cost anomaly

## Impact

AWS cost increased unexpectedly for the lab account or a specific service.

## First 5 minutes

1. Open AWS Cost Anomaly Detection alert details.
2. Identify service, account, linked resources, and time window.
3. Check recent platform changes in Git.
4. Check for common lab cost drivers: Load Balancer, NAT Gateway, EBS, CloudWatch logs, EKS node groups.
5. Stop or scale down non-critical lab resources after preserving evidence.

## Commands

```powershell
aws ce get-cost-and-usage --time-period Start=<yyyy-mm-dd>,End=<yyyy-mm-dd> --granularity DAILY --metrics UnblendedCost
kubectl get svc -A
kubectl get pvc -A
kubectl get pods -A
```

## Recovery

- Remove unused LoadBalancer services.
- Delete unused PVCs/EBS volumes.
- Reduce log retention if ingestion is excessive.
- Add or fix tags: `Project`, `Owner`, `Environment`, `CostCenter`, `TTL`.

