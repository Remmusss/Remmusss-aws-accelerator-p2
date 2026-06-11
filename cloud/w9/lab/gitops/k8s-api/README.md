# Ship Smartly - API release guard

Owner email: trandinhminhquan207@gmail.com

## Goal

Release the `api` service through GitOps, measure quality with Prometheus, and let Argo Rollouts stop a bad canary automatically before it reaches 100%.

## Decisions

- GitOps remains the source of truth: every release change is made in `cloud/w9/lab/gitops/k8s-api/api.yaml`, committed, pushed, and synced by Argo CD.
- The service-level objective is `95% successful HTTP requests over 5 minutes`.
- `PrometheusRule` records `api:request_success_rate:5m` and fires `ApiSLOViolation` when success rate is below `0.95` for 2 minutes.
- `AnalysisTemplate/api-success-rate` queries Prometheus during rollout steps. A result below `0.95` fails the analysis and Argo Rollouts aborts the canary.
- The default manifest keeps `ERROR_RATE=0` so the repository converges to a healthy state. To prove auto-abort, create a temporary Git commit with `ERROR_RATE=1`, push it, observe abort, then `git revert` that commit.

## Prometheus query

```promql
(
  sum(rate(flask_http_request_total{namespace="demo", service="api", status!~"5.."}[1m]))
  /
  sum(rate(flask_http_request_total{namespace="demo", service="api"}[1m]))
) or vector(1)
```

The query treats no traffic as healthy with `or vector(1)`. During a real canary demo, keep load running so the query measures actual requests.

## Demo commands

```powershell
kubectl -n demo run api-load --image=busybox --restart=Never -- `
  sh -c "while true; do wget -qO- http://api:8080/ >/dev/null; sleep 0.2; done"

kubectl-argo-rollouts.exe get rollout api -n demo --watch
```

Good release:

```powershell
# Change VERSION only, keep ERROR_RATE "0"
git add cloud/w9/lab/gitops/k8s-api/api.yaml
git commit -m "api good canary"
git push
```

Bad release for auto-abort proof:

```powershell
# Change VERSION to a new value and ERROR_RATE to "1"
git add cloud/w9/lab/gitops/k8s-api/api.yaml
git commit -m "api bad canary"
git push

kubectl-argo-rollouts.exe get rollout api -n demo --watch
kubectl -n demo describe rollout api

git revert HEAD
git push
```

## Email alert

Alertmanager is configured in `cloud/w9/lab/argocd/apps/kube-prometheus-stack.yaml` with receiver `personal-email` and target `trandinhminhquan207@gmail.com`.

Before the email can actually be sent, replace the placeholder SMTP password in the Helm values with a real Gmail app password or another SMTP credential. Do not commit real credentials to a public repository unless this is a throwaway lab account.
