# Ship Smartly - API release guard

Owner email: stored outside Git in `monitoring/alertmanager-private-config`.

## Goal

Release the `api` service through GitOps, measure quality with Prometheus, and let Argo Rollouts stop a bad canary automatically before it reaches 100%.

## Decisions

- GitOps remains the source of truth: every release change is made in `cloud/w9/lab/gitops/k8s-api/api.yaml`, committed, pushed, and synced by Argo CD.
- The service-level objective is `95% successful HTTP requests over 5 minutes`.
- `PrometheusRule` records `api:request_success_rate:5m` as the SLO signal and fires `ApiSLOViolation` from a 1-minute fast-burn query when success rate is below `0.95` for 30 seconds. The shorter alert window is intentional for a lab demo where the bad canary is aborted quickly.
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

Alert routing is configured by a private Alertmanager Secret, not by embedding SMTP credentials or personal email in public Helm values.

The public repository only references Secret name `monitoring/alertmanager-private-config`. The Secret contains `alertmanager.yaml` with receiver, route, target email, SMTP username, and SMTP app password.

Create `cloud/w9/lab/secrets/.env` locally from `.env.example`, then apply the Secret:

```powershell
Copy-Item cloud/w9/lab/secrets/.env.example cloud/w9/lab/secrets/.env
notepad cloud/w9/lab/secrets/.env
powershell -ExecutionPolicy Bypass -File cloud/w9/lab/secrets/apply-alertmanager-secret.ps1
```

To change email or password later, edit only the local `.env` file and rerun the script.

This keeps the public repository clean. For a stricter GitOps setup, replace the manual Secret with SealedSecrets, SOPS-encrypted Secret, or External Secrets Operator connected to a secret manager.
