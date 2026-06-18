# Gatekeeper install

Install Gatekeeper with Helm:

```powershell
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper `
  --namespace gatekeeper-system `
  --create-namespace
```

Verify:

```powershell
kubectl -n gatekeeper-system get pods
kubectl get crd | Select-String gatekeeper
```

Apply policy in this order. Do not apply templates and constraints in the same first pass because the ConstraintTemplate creates the constraint CRD that the Constraint depends on.

```powershell
kubectl apply -k cloud/w10/day-a/policies/constrainttemplates
kubectl apply -k cloud/w10/day-a/policies/constraints
```

The constraints use `enforcementAction: deny` because W10 requires cluster-level enforcement, not audit-only reporting.
