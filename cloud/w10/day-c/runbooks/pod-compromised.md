# Runbook - Pod compromised

## Impact

A pod may be running unexpected code, making suspicious network calls, or using an untrusted image.

## First 5 minutes

1. Identify namespace, pod, image, node, and owner labels.
2. Capture logs and events.
3. Check whether the image was signed and admitted by policy.
4. Contain with NetworkPolicy or scale down if the pod is actively causing harm.
5. Preserve evidence before deleting unless immediate containment is required.

## Commands

```powershell
kubectl -n <ns> get pod <pod> -o wide
kubectl -n <ns> get pod <pod> -o yaml
kubectl -n <ns> logs <pod> --previous
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

## Recovery

- Rebuild image from trusted source.
- Scan with Trivy.
- Sign with Cosign.
- Redeploy through GitOps.
- Confirm admission policy and runtime metrics are healthy.

