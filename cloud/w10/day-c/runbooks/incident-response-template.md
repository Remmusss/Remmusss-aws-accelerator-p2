# Incident response runbook template

## Incident name

## Impact

## Symptoms

## Detection signal

## First 5 minutes

1. Confirm the affected namespace, workload, pod, image, and node.
2. Preserve short-lived evidence: events, logs, current manifest, rollout status.
3. Decide whether to contain immediately or collect more evidence.
4. Assign owner and communication channel.

## Commands

```powershell
kubectl -n <namespace> get pods -o wide
kubectl -n <namespace> get events --sort-by=.lastTimestamp
kubectl -n <namespace> describe pod <pod>
kubectl -n <namespace> logs <pod> --previous
```

## Containment

## Recovery

## Validation

## Escalation

## Postmortem notes

