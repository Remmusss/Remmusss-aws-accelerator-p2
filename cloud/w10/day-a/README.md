# W10 Day A - Cách chạy

## 1. Mục tiêu

Chạy RBAC và Gatekeeper admission policy cho Day A:

- Tạo namespace và ServiceAccount cho `developer`, `viewer`, `sre`.
- Apply RBAC đúng scope.
- Cài Gatekeeper.
- Apply `ConstraintTemplate` trước, `Constraint` sau.
- Test RBAC bằng `kubectl auth can-i`.
- Test policy bằng manifest valid/invalid.

## 2. Yêu cầu trước khi chạy

Cần có:

```powershell
kubectl version
kubectl get nodes
helm version
```

Cluster cần cho phép cài CRD/webhook vì Gatekeeper sẽ tạo CRD và admission webhook.

## 3. Apply RBAC

```powershell
kubectl apply -k cloud/w10/day-a/rbac
```

Kiểm tra:

```powershell
kubectl get ns platform-system app-dev app-prod security
kubectl -n app-dev get sa developer-sa viewer-sa
kubectl -n platform-system get sa sre-sa
kubectl -n app-dev get role,rolebinding
kubectl get clusterrole w10-sre
kubectl get clusterrolebinding w10-sre
```

## 4. Test RBAC

Chạy các lệnh trong:

```text
cloud/w10/day-a/evidence/rbac-can-i.md
```

Lệnh chính:

```powershell
kubectl auth can-i create deployments -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i get secrets -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i delete namespaces --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i list pods -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i delete deployments -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i list nodes --as system:serviceaccount:platform-system:sre-sa
```

Ghi output thật vào `evidence/rbac-can-i.md`.

## 5. Cài Gatekeeper

```powershell
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper `
  --namespace gatekeeper-system `
  --create-namespace
```

Kiểm tra:

```powershell
kubectl -n gatekeeper-system get pods
kubectl get crd | Select-String gatekeeper
```

## 6. Apply policy đúng thứ tự

Apply `ConstraintTemplate` trước:

```powershell
kubectl apply -k cloud/w10/day-a/policies/constrainttemplates
```

Đợi CRD constraint được tạo, sau đó apply `Constraint`:

```powershell
kubectl apply -k cloud/w10/day-a/policies/constraints
```

Kiểm tra:

```powershell
kubectl get constrainttemplates
kubectl get constraints
```

## 7. Test Gatekeeper policy

Manifest hợp lệ:

```powershell
kubectl apply -f cloud/w10/day-a/policies/samples/valid-pod.yaml
```

Manifest sai, kỳ vọng bị reject:

```powershell
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-privileged-pod.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-resources.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-latest-image.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-labels.yaml
```

Ghi output thật vào:

```text
cloud/w10/day-a/evidence/gatekeeper-policy-tests.md
```

## 8. Cleanup test pod

```powershell
kubectl -n app-dev delete pod valid-w10-pod --ignore-not-found
```

