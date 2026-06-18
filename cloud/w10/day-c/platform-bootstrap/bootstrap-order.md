# Bootstrap order

1. Create or connect to a fresh Kubernetes cluster.
2. Create system namespaces:

```powershell
kubectl apply -f cloud/w10/day-c/platform-bootstrap/namespaces/system-namespaces.yaml
```

3. Install Argo CD.
4. Install Gatekeeper and apply Day A policy.
5. Install External Secrets Operator and apply Day B ESO manifests.
6. Install Kyverno if using Day B `verifyImages`.
7. Install kube-prometheus-stack.
8. Install Argo Rollouts.
9. Apply ResourceQuota and LimitRange:

```powershell
kubectl apply -k cloud/w10/day-c/platform-bootstrap/quotas
```

10. Bootstrap Argo CD root app:

```powershell
kubectl apply -f cloud/w10/day-c/platform-bootstrap/argocd-apps/root.yaml
```

11. Check platform health:

```powershell
kubectl -n argocd get applications
kubectl -n app-dev describe resourcequota app-dev-quota
kubectl -n app-dev describe limitrange app-dev-defaults
```

Record start/end time in `cloud/w10/day-c/evidence/bootstrap-timing.md`.

