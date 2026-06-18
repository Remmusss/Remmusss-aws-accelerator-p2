# Runbook - Secret rotation failed

## Impact

The app does not observe the new secret value within the expected 60-second window.

## First 5 minutes

1. Confirm the AWS Secrets Manager secret version changed.
2. Check ESO `ExternalSecret` condition.
3. Check Kubernetes Secret updated.
4. Check pod restart count.
5. Check whether the app reads mounted files dynamically or only reads env vars at startup.

## Commands

```powershell
aws secretsmanager describe-secret --secret-id /w10/dev/demo-api
kubectl -n app-dev get externalsecret demo-api-secret
kubectl -n app-dev describe externalsecret demo-api-secret
kubectl -n app-dev get secret demo-api-secret -o yaml
kubectl -n app-dev get pod -l app.kubernetes.io/name=secret-reader
```

## Recovery

- Fix IAM permission if ESO cannot read AWS Secrets Manager.
- Fix `SecretStore` region or service account if auth fails.
- Restart app only as a last resort; the target design is no-restart rotation via mounted Secret volume.

