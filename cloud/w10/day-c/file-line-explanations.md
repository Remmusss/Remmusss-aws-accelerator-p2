# W10 Day C - Giải thích từng dòng/cụm dòng trong file

Tài liệu này giải thích các dòng và thuộc tính đang xuất hiện trong các file Day C. Các dòng/field đã giải thích ở phần chung sẽ không lặp lại.

## 1. Dòng chung dùng lại nhiều file

```yaml
apiVersion: ...
kind: ...
metadata:
  name: ...
  namespace: ...
labels:
```

Cấu trúc resource Kubernetes. `labels` dùng cho ownership, environment và grouping.

```yaml
---
```

Tách nhiều YAML document trong cùng một file.

## 2. `.gitignore`

```gitignore
evidence/*.log
evidence/*.out
evidence/*.png
evidence/*.jpg
rendered/
tmp/
```

Không commit log, output, screenshot hoặc render tạm từ quá trình chạy lab.

## 3. `platform-bootstrap/namespaces/system-namespaces.yaml`

```yaml
kind: Namespace
name: argocd
```

Namespace cho Argo CD.

```yaml
name: monitoring
```

Namespace cho Prometheus/Grafana/Alertmanager.

```yaml
name: gatekeeper-system
```

Namespace cho Gatekeeper.

```yaml
name: external-secrets
```

Namespace cho External Secrets Operator.

```yaml
name: kyverno
```

Namespace cho Kyverno image verification policy.

```yaml
name: app-dev
```

Namespace app để áp quota, ESO secret và workload.

## 4. `platform-bootstrap/quotas/resourcequota.yaml`

```yaml
kind: ResourceQuota
name: app-dev-quota
namespace: app-dev
```

Giới hạn tổng tài nguyên được dùng trong namespace `app-dev`.

```yaml
spec:
  hard:
```

`hard` là ngưỡng quota tối đa.

```yaml
requests.cpu: "2"
requests.memory: 4Gi
```

Tổng CPU/memory request trong namespace không vượt quá giá trị này.

```yaml
limits.cpu: "4"
limits.memory: 8Gi
```

Tổng CPU/memory limit trong namespace không vượt quá giá trị này.

```yaml
pods: "20"
services: "10"
secrets: "20"
configmaps: "20"
```

Giới hạn số lượng object để tránh namespace bị spam resource.

## 5. `platform-bootstrap/quotas/limitrange.yaml`

```yaml
kind: LimitRange
name: app-dev-defaults
```

Đặt default/min/max resource cho container trong namespace.

```yaml
type: Container
```

Rule áp dụng cho container.

```yaml
defaultRequest:
  cpu: 100m
  memory: 128Mi
```

Request mặc định nếu container không khai báo.

```yaml
default:
  cpu: 500m
  memory: 512Mi
```

Limit mặc định nếu container không khai báo.

```yaml
min:
  cpu: 50m
  memory: 64Mi
```

Giá trị tối thiểu được phép.

```yaml
max:
  cpu: "1"
  memory: 1Gi
```

Giá trị tối đa cho một container.

## 6. Kustomization files

Áp dụng cho:

```text
platform-bootstrap/quotas/kustomization.yaml
platform-bootstrap/argocd-apps/kustomization.yaml
kustomization.yaml
```

```yaml
kind: Kustomization
resources:
```

Gom nhiều manifest để chạy bằng `kubectl apply -k`.

Top-level Day C include namespace hệ thống và quota để bootstrap phần Kubernetes-native trước.

## 7. Argo CD Application files

Áp dụng cho `platform-bootstrap/argocd-apps/*.yaml`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
```

Argo CD Application, yêu cầu Argo CD CRD đã được cài.

```yaml
metadata:
  name: w10-root
  namespace: argocd
```

Application nằm trong namespace `argocd`.

```yaml
spec:
  project: default
```

Dùng Argo CD project mặc định.

```yaml
source:
  repoURL: https://github.com/Remmusss/Remmusss-aws-accelerator-p2.git
  targetRevision: main
  path: ...
```

Repo, branch và path mà Argo CD đọc desired state.

```yaml
destination:
  server: https://kubernetes.default.svc
  namespace: ...
```

Deploy vào cluster hiện tại. `namespace` là namespace đích mặc định.

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Argo CD tự sync, xóa resource không còn trong Git, và sửa drift.

```yaml
syncOptions:
  - CreateNamespace=true
```

Cho phép Argo CD tạo namespace nếu thiếu.

```yaml
syncOptions:
  - ServerSideApply=true
```

Dùng server-side apply, phù hợp hơn với CRD/policy resource.

Các app con:

- `day-a-rbac.yaml`: sync `cloud/w10/day-a/rbac`.
- `day-a-policies.yaml`: sync `cloud/w10/day-a/policies`.
- `day-b-eso.yaml`: sync `cloud/w10/day-b/eso`.
- `day-c-quotas.yaml`: sync `cloud/w10/day-c/platform-bootstrap/quotas`.

## 8. Runbook markdown files

Áp dụng cho `runbooks/*.md`.

Các file này không phải manifest. Chúng là quy trình vận hành khi có sự cố:

- `incident-response-template.md`: mẫu chung.
- `pod-compromised.md`: xử lý pod nghi bị compromise.
- `rollout-failed.md`: xử lý rollout/canary fail.
- `secret-rotation-failed.md`: xử lý ESO/secret rotation fail.
- `cost-anomaly.md`: xử lý cảnh báo chi phí AWS.

Các cụm lệnh như:

```powershell
kubectl -n <ns> get pod <pod> -o wide
kubectl -n <ns> logs <pod> --previous
kubectl -n <ns> describe pod <pod>
```

dùng để thu thập evidence và triage.

## 9. Chaos markdown files

Áp dụng cho `chaos/*.md`.

```powershell
kubectl -n app-dev delete pod <pod-name>
```

Xóa một pod để kiểm tra Deployment/ReplicaSet/Rollout có tạo pod thay thế không.

```powershell
kubectl -n app-dev get pods -w
kubectl -n app-dev get endpoints
```

Theo dõi phục hồi và kiểm tra service còn endpoint không.

## 10. Cost guard markdown files

Áp dụng cho `cost-guard/*.md`.

```text
Project=W10
Owner=<student-name>
Environment=dev
CostCenter=training
TTL=<yyyy-mm-dd>
```

Tag AWS dùng cho cost allocation, cleanup và ownership.

Cost Anomaly Detection dùng để phát hiện chi phí AWS tăng bất thường do EKS, Load Balancer, NAT Gateway, EBS hoặc CloudWatch logs.

## 11. Evidence markdown files

Áp dụng cho `evidence/*.md`.

Các file này là nơi ghi output thật:

- `bootstrap-timing.md`: thời gian bootstrap fresh cluster.
- `quota-tests.md`: kết quả quota/limitrange.
- `chaos-test.md`: kết quả chaos test.
- `runbook-drill.md`: kết quả thực hành runbook.

