# Chaos test - Pod delete

## Goal

Verify that a replicated workload can recover after one pod is deleted.

## Steps

```powershell
kubectl -n app-dev get pods
kubectl -n app-dev delete pod <pod-name>
kubectl -n app-dev get pods -w
kubectl -n app-dev get endpoints
```

## Expected result

- A replacement pod is created.
- Service endpoints remain available if another replica exists.
- Alert should not fire for a very short disruption unless the SLO threshold is intentionally strict.

Record evidence in `cloud/w10/day-c/evidence/chaos-test.md`.

