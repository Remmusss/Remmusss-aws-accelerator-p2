# W10 platform bootstrap

This folder describes how to rebuild the W10 mini platform from a fresh cluster.

Target flow:

```text
Git commit
  -> Argo CD sync
  -> workload deploys with rollout/canary
  -> image is scanned and signed
  -> admission checks manifest and image signature
  -> secret comes from AWS Secrets Manager through ESO
  -> Prometheus observes runtime metrics
  -> runbook handles failures
  -> ResourceQuota/LimitRange control namespace usage
  -> AWS Cost Anomaly Detection catches billing spikes
```

Use `bootstrap-order.md` as the operational sequence. Use the manifests under `namespaces/`, `quotas/`, `policies/`, and `argocd-apps/` as GitOps inputs.

