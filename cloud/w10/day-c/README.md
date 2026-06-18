# W10 Day C - Cách chạy

## 1. Mục tiêu

Chạy phần Platform Integration + Runbook + Cost Guard:

- Chuẩn bị namespace hệ thống.
- Apply `ResourceQuota` và `LimitRange`.
- Bootstrap Argo CD App-of-Apps skeleton.
- Kiểm tra platform integration với Day A và Day B.
- Chạy chaos test cơ bản.
- Điền runbook/evidence.
- Thiết lập AWS Cost Anomaly Detection theo hướng dẫn.

## 2. Yêu cầu trước khi chạy

Cần có:

```powershell
kubectl get nodes
helm version
aws sts get-caller-identity
git --version
```

Cần cài hoặc đã có:

- Argo CD.
- Gatekeeper.
- External Secrets Operator.
- Kyverno nếu dùng image verification.
- kube-prometheus-stack nếu test observability/canary.
- Argo Rollouts nếu test rollout/canary.

Xem thêm:

```text
cloud/w10/day-c/platform-bootstrap/prerequisites.md
```

## 3. Apply namespace và quota

Apply entrypoint Day C:

```powershell
kubectl apply -k cloud/w10/day-c
```

Hoặc apply riêng:

```powershell
kubectl apply -f cloud/w10/day-c/platform-bootstrap/namespaces/system-namespaces.yaml
kubectl apply -k cloud/w10/day-c/platform-bootstrap/quotas
```

Kiểm tra:

```powershell
kubectl get ns argocd monitoring gatekeeper-system external-secrets kyverno app-dev
kubectl -n app-dev describe resourcequota app-dev-quota
kubectl -n app-dev describe limitrange app-dev-defaults
```

Ghi kết quả quota vào:

```text
cloud/w10/day-c/evidence/quota-tests.md
```

## 4. Bootstrap theo thứ tự

Làm theo:

```text
cloud/w10/day-c/platform-bootstrap/bootstrap-order.md
```

Thứ tự chính:

1. Cluster nền.
2. Namespace hệ thống.
3. Argo CD.
4. Gatekeeper + Day A policies.
5. External Secrets Operator + Day B ESO.
6. Kyverno nếu verify image.
7. kube-prometheus-stack.
8. Argo Rollouts.
9. Quota/LimitRange.
10. Argo CD root app.

Ghi thời gian bootstrap vào:

```text
cloud/w10/day-c/evidence/bootstrap-timing.md
```

## 5. Apply Argo CD root app

Trước khi apply, kiểm tra repo URL trong:

```text
cloud/w10/day-c/platform-bootstrap/argocd-apps/root.yaml
```

Apply:

```powershell
kubectl apply -f cloud/w10/day-c/platform-bootstrap/argocd-apps/root.yaml
```

Kiểm tra:

```powershell
kubectl -n argocd get applications
```

Lưu ý: root app trỏ tới `cloud/w10/day-c/platform-bootstrap/argocd-apps`, trong đó có app con cho Day A RBAC, Day A policies, Day B ESO và Day C quotas.

## 6. Chạy chaos test pod delete

Xem hướng dẫn:

```text
cloud/w10/day-c/chaos/pod-delete-test.md
```

Lệnh mẫu:

```powershell
kubectl -n app-dev get pods
kubectl -n app-dev delete pod <pod-name>
kubectl -n app-dev get pods -w
kubectl -n app-dev get endpoints
```

Ghi kết quả vào:

```text
cloud/w10/day-c/evidence/chaos-test.md
```

## 7. Thực hành runbook

Runbook có sẵn:

```text
cloud/w10/day-c/runbooks/pod-compromised.md
cloud/w10/day-c/runbooks/rollout-failed.md
cloud/w10/day-c/runbooks/secret-rotation-failed.md
cloud/w10/day-c/runbooks/cost-anomaly.md
```

Chọn ít nhất một runbook để drill và ghi lại:

```text
cloud/w10/day-c/evidence/runbook-drill.md
```

## 8. Cost guard

Thiết lập AWS Cost Anomaly Detection theo:

```text
cloud/w10/day-c/cost-guard/cost-anomaly-detection.md
```

Tagging standard:

```text
cloud/w10/day-c/cost-guard/tagging-standard.md
```

Ghi lại monitor name, threshold, subscriber và ngày tạo trong evidence hoặc screenshot nội bộ. Không commit thông tin nhạy cảm.

