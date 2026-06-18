# Platform policies

Day C reuses the enforceable guardrails created in:

- `cloud/w10/day-a/rbac`
- `cloud/w10/day-a/policies`
- `cloud/w10/day-b/signing/verify-policy.yaml`

Do not duplicate policy logic here. This folder exists to document that platform bootstrap must apply RBAC, Gatekeeper constraints, and image signature verification before workload deployment.

Recommended order:

```powershell
kubectl apply -k cloud/w10/day-a/rbac
kubectl apply -k cloud/w10/day-a/policies
kubectl apply -f cloud/w10/day-b/signing/verify-policy.yaml
```

