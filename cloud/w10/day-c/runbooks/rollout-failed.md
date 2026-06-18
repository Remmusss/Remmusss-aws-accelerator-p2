# Runbook - Rollout failed

## Impact

A new version failed canary analysis or became unhealthy during rollout.

## First 5 minutes

1. Check Rollout phase and current step.
2. Check AnalysisRun status.
3. Check Prometheus query and recent metrics.
4. Confirm stable ReplicaSet still serves traffic.
5. Do not manually promote until the cause is understood.

## Commands

```powershell
kubectl argo rollouts get rollout <name> -n <ns>
kubectl -n <ns> get analysisrun
kubectl -n <ns> describe analysisrun <name>
kubectl -n <ns> get rs,pods,svc
```

## Recovery

- Abort rollout if the new version is bad.
- Fix image/config and push a new Git revision.
- Confirm rollout becomes Healthy and SLO returns to normal.

