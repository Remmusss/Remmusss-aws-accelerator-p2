# Ship Smartly evidence

Date: 2026-06-12

Owner email: trandinhminhquan207@gmail.com

## GitOps commits

- Release guard implementation: `1d86f8d [W9-LAB] add ship smartly release guards`
- Bad canary proof commit: `b284738 [W9-LAB] demo bad canary`
- Git rollback proof: `393aafb Revert "[W9-LAB] demo bad canary"`

## Cluster result

All Argo CD applications returned to synced and healthy:

```text
api                     Synced        Healthy
argo-rollouts           Synced        Healthy
fe-be                   Synced        Healthy
kube-prometheus-stack   Synced        Healthy
root                    Synced        Healthy
web                     Synced        Healthy
```

The bad canary was stopped by Argo Rollouts analysis:

```text
Status:  Degraded
Message: RolloutAborted: Rollout aborted update to revision 3:
Metric "api-success-rate" assessed Failed due to failed (2) > failureLimit (1)
```

After `git revert` and push, the rollout returned to healthy:

```text
Status:          Healthy
Strategy:        Canary
Step:            5/5
SetWeight:       100
ActualWeight:    100
Replicas:
  Desired:       4
  Current:       4
  Updated:       4
  Ready:         4
  Available:     4
```

## Prometheus rule loaded

Prometheus loaded the custom rule group from namespace `demo`:

```text
group: api.slo
record: api:request_success_rate:5m
alert: ApiSLOViolation
health: ok
```

## Email alert note

Alertmanager routes `Api*` alerts in namespace `demo` to `trandinhminhquan207@gmail.com`.

The repository intentionally keeps `smtp_auth_password: CHANGE_ME_WITH_GMAIL_APP_PASSWORD`. Replace it with a real SMTP app password in a private lab repo or secret-managed setup before demonstrating actual email delivery.
