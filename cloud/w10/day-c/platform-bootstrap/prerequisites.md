# Prerequisites

Required tools:

```powershell
kubectl version
helm version
aws sts get-caller-identity
git --version
```

Required controllers before app workload:

- Argo CD.
- Gatekeeper.
- External Secrets Operator.
- Kyverno if image signature verification is enabled.
- kube-prometheus-stack.
- Argo Rollouts.

Required AWS setup:

- AWS account for lab.
- AWS Secrets Manager secret `/w10/dev/demo-api`.
- IAM role for ESO if using EKS.
- AWS Cost Anomaly Detection monitor.

Required repository inputs:

- Day A RBAC and Gatekeeper policies.
- Day B ESO manifests and image verification policy.
- Day C ResourceQuota, LimitRange, runbooks, and cost guard docs.

