# W10 Day A - Giải thích từng dòng/cụm dòng trong file

Tài liệu này giải thích các dòng và thuộc tính đang xuất hiện trong các file Day A. Các dòng/field đã giải thích ở phần chung sẽ không lặp lại ở từng file.

## 1. Dòng chung dùng lại nhiều file

```yaml
apiVersion: ...
```

Chỉ API group/version của resource. Ví dụ `v1` là Kubernetes core API, `rbac.authorization.k8s.io/v1` là API của RBAC, `templates.gatekeeper.sh/v1` là API của Gatekeeper `ConstraintTemplate`.

```yaml
kind: ...
```

Chỉ loại resource Kubernetes, ví dụ `Namespace`, `Role`, `Pod`, `ConstraintTemplate`.

```yaml
metadata:
  name: ...
  namespace: ...
```

`metadata.name` là tên resource. `metadata.namespace` là namespace chứa resource nếu resource đó là namespace-scoped.

```yaml
labels:
  app.kubernetes.io/name: ...
  app.kubernetes.io/part-of: ...
  owner: ...
  environment: ...
```

Label dùng cho ownership, lọc resource, policy, cost và incident response. Day A có policy bắt workload phải có `owner`, `app.kubernetes.io/name`, `app.kubernetes.io/part-of`.

```yaml
---
```

Tách nhiều YAML document trong cùng một file.

## 2. `rbac/namespaces.yaml`

```yaml
kind: Namespace
```

Tạo namespace. Namespace là ranh giới logic để tách app, platform và security.

```yaml
name: platform-system
```

Namespace cho thành phần vận hành platform hoặc ServiceAccount `sre-sa`.

```yaml
name: app-dev
```

Namespace chính cho developer deploy workload và chạy sample test.

```yaml
name: app-prod
```

Namespace mô phỏng production, dùng cho mở rộng hoặc kiểm tra policy cross-environment.

```yaml
name: security
```

Namespace dành cho tài nguyên security/policy nếu cần tách khỏi platform.

## 3. `rbac/serviceaccounts.yaml`

```yaml
kind: ServiceAccount
```

Tạo identity trong Kubernetes. Lab dùng ServiceAccount để mô phỏng user/role.

```yaml
name: developer-sa
namespace: app-dev
```

Identity đại diện developer trong namespace `app-dev`.

```yaml
name: viewer-sa
namespace: app-dev
```

Identity đại diện viewer read-only.

```yaml
name: sre-sa
namespace: platform-system
```

Identity đại diện SRE/platform operator.

## 4. `rbac/roles.yaml`

```yaml
kind: Role
```

Tạo quyền trong phạm vi một namespace.

```yaml
name: developer
namespace: app-dev
```

Role `developer` chỉ có hiệu lực trong `app-dev`.

```yaml
rules:
```

Danh sách rule cấp quyền.

```yaml
apiGroups: [""]
```

Core API group, dùng cho `pods`, `services`, `configmaps`, `events`.

```yaml
resources: ["pods", "pods/log", "services", "configmaps", "events"]
verbs: ["get", "list", "watch"]
```

Cho phép developer đọc workload cơ bản, log pod và event để debug.

```yaml
resources: ["services", "configmaps"]
verbs: ["create", "update", "patch", "delete"]
```

Cho phép developer tạo/sửa/xóa service và configmap trong namespace app.

```yaml
apiGroups: ["apps"]
resources: ["deployments", "replicasets"]
```

Quyền trên workload thuộc API group `apps`.

```yaml
apiGroups: ["batch"]
resources: ["jobs", "cronjobs"]
```

Quyền trên workload batch.

```yaml
name: viewer
```

Role viewer chỉ có quyền đọc.

```yaml
verbs: ["get", "list", "watch"]
```

Viewer không có quyền ghi vì không có `create`, `update`, `patch`, `delete`.

## 5. `rbac/rolebindings.yaml`

```yaml
kind: RoleBinding
```

Gắn Role trong namespace với identity.

```yaml
subjects:
  - kind: ServiceAccount
    name: developer-sa
    namespace: app-dev
```

Subject là identity nhận quyền. Ở đây là ServiceAccount `developer-sa`.

```yaml
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
```

`roleRef` chỉ Role được bind. Ở đây `developer-sa` nhận Role `developer`.

Các block `viewer` tương tự, nhưng bind `viewer-sa` với Role `viewer`.

## 6. `rbac/clusterroles.yaml`

```yaml
kind: ClusterRole
```

Tạo quyền cấp cluster hoặc quyền có thể dùng nhiều namespace.

```yaml
name: w10-sre
```

ClusterRole cho SRE, không dùng `cluster-admin`.

```yaml
resources: ["nodes", "namespaces", ...]
```

Cho SRE xem tài nguyên cluster-level để điều tra sự cố.

```yaml
apiGroups: ["templates.gatekeeper.sh"]
resources: ["constrainttemplates"]
verbs: ["get", "list", "watch", "create", "update", "patch"]
```

Cho SRE xem/tạo/sửa Gatekeeper template, nhưng không có quyền `delete`.

```yaml
apiGroups: ["constraints.gatekeeper.sh"]
resources: ["*"]
```

Cho phép thao tác nhiều loại Gatekeeper constraint vì mỗi `ConstraintTemplate` tạo ra một kind constraint riêng.

## 7. `rbac/clusterrolebindings.yaml`

```yaml
kind: ClusterRoleBinding
```

Gắn ClusterRole với identity ở phạm vi toàn cluster.

```yaml
subjects:
  - kind: ServiceAccount
    name: sre-sa
    namespace: platform-system
```

Identity nhận quyền là `sre-sa`.

```yaml
roleRef:
  kind: ClusterRole
  name: w10-sre
```

Gắn `sre-sa` với ClusterRole `w10-sre`.

## 8. `rbac/kustomization.yaml` và `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
```

Khai báo thư mục này là Kustomize package. `resources` liệt kê file/thư mục được render khi chạy `kubectl apply -k`.

Top-level `cloud/w10/day-a/kustomization.yaml` chỉ include `rbac` để tránh apply Gatekeeper `Constraint` trước khi `ConstraintTemplate` tạo CRD.

## 9. Gatekeeper `ConstraintTemplate`

Áp dụng cho các file trong `policies/constrainttemplates/`.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
```

Định nghĩa một loại policy custom cho Gatekeeper.

```yaml
metadata:
  name: k8srequiredw10labels
```

Tên template. Tên này phải lowercase.

```yaml
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredW10Labels
```

Tạo ra một constraint kind mới để dùng trong `policies/constraints/`.

```yaml
validation:
  openAPIV3Schema:
```

Schema cho `spec.parameters` của constraint. File required-labels dùng schema này để khai báo `labels` là array string.

```yaml
targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
```

Policy chạy trong admission flow của Kubernetes. `rego` là logic kiểm tra.

### Rego dùng trong template

```rego
package ...
```

Namespace logic Rego.

```rego
input.review.object
```

Kubernetes object đang được admission kiểm tra.

```rego
input.parameters
```

Tham số truyền từ Constraint.

```rego
violation[{"msg": msg}] { ... }
```

Nếu block này match, Gatekeeper báo vi phạm và reject khi `enforcementAction: deny`.

```rego
contains`, `endswith`, `count`, `sprintf`, `not`
```

Các hàm/toán tử dùng để kiểm tra image tag, số label thiếu và tạo message lỗi.

## 10. Gatekeeper `Constraint`

Áp dụng cho các file trong `policies/constraints/`.

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredW10Labels
```

Kind này được tạo bởi `ConstraintTemplate`.

```yaml
spec:
  enforcementAction: deny
```

Nếu vi phạm, Kubernetes API reject request.

```yaml
match:
  excludedNamespaces:
```

Không áp policy lên namespace hệ thống như `kube-system`, `gatekeeper-system`, `argocd`, `monitoring`, `external-secrets`, `kyverno`.

```yaml
kinds:
  - apiGroups: [""]
    kinds: ["Pod"]
```

Chỉ áp policy lên kind/API group được khai báo.

```yaml
parameters:
  labels:
```

Tham số truyền vào Rego. Required-labels constraint dùng phần này để định nghĩa label bắt buộc.

## 11. Sample pod/deployment

Áp dụng cho `policies/samples/*.yaml`.

```yaml
kind: Pod
```

Tạo pod trực tiếp để test admission.

```yaml
kind: Deployment
```

Tạo workload controller để test required labels trên resource `apps`.

```yaml
spec:
  securityContext:
    runAsNonRoot: true
```

Yêu cầu pod chạy non-root.

```yaml
securityContext:
  privileged: true
```

Field cố tình sai trong `invalid-privileged-pod.yaml`; Gatekeeper phải reject.

```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
```

Hardening runtime trong sample hợp lệ. Lab hiện chưa enforce cả ba field này, nhưng chúng thể hiện baseline an toàn.

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

`requests` dùng cho scheduling. `limits` là trần runtime. Constraint `require-container-requests-limits` bắt buộc bốn field CPU/memory này.

```yaml
image: nginx:1.27-alpine
```

Image có tag cụ thể, hợp lệ.

```yaml
image: nginx:latest
```

Image dùng tag mutable, bị constraint `disallow-latest-image-tag` reject.

```yaml
spec.replicas
spec.selector.matchLabels
spec.template.metadata.labels
spec.template.spec.containers
```

Các field của Deployment. `invalid-missing-labels.yaml` cố tình thiếu label ownership ở `metadata.labels` của Deployment để test required-labels constraint.

## 12. Evidence markdown

```text
evidence/rbac-can-i.md
evidence/gatekeeper-policy-tests.md
```

Hai file này không phải manifest. Chúng là nơi ghi lệnh, output thật và kết quả pass/fail khi chạy lab.

