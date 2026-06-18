# W10 Day A - Learning Guide: RBAC + Admission Policy

## 1. Cách học Day A

Day A dùng đúng hai nhóm kỹ thuật:

- Kubernetes RBAC để trả lời: **ai được phép làm gì**.
- Gatekeeper admission policy để trả lời: **manifest nào được phép đi vào cluster**.

Learning guide này chỉ giải thích các lệnh, biến, field và thuộc tính đang được dùng trong lab Day A. Khi đọc manifest, hãy đối chiếu trực tiếp với các thư mục:

```text
cloud/w10/day-a/rbac/
cloud/w10/day-a/policies/
cloud/w10/day-a/policies/samples/
cloud/w10/day-a/evidence/
```

## 2. Các lệnh cần hiểu

### 2.1. `kubectl apply -k`

Được dùng trong lab:

```powershell
kubectl apply -k cloud/w10/day-a/rbac
kubectl apply -k cloud/w10/day-a
kubectl apply -k cloud/w10/day-a/policies/constrainttemplates
kubectl apply -k cloud/w10/day-a/policies/constraints
```

Giải thích:

- `kubectl apply`: gửi desired state lên Kubernetes API.
- `-k`: đọc thư mục Kustomize có file `kustomization.yaml`.
- `cloud/w10/day-a/rbac`: apply toàn bộ RBAC resource được liệt kê trong `rbac/kustomization.yaml`.
- `cloud/w10/day-a`: entrypoint top-level, hiện chỉ apply RBAC để tránh apply Gatekeeper constraint sai thứ tự.
- `policies/constrainttemplates`: apply `ConstraintTemplate` trước.
- `policies/constraints`: apply `Constraint` sau khi template đã tạo CRD tương ứng.

Vì sao cần học:

- Lab dùng Kustomize để gom nhiều YAML thành một đơn vị apply.
- Nếu không hiểu `-k`, bạn sẽ không biết file nào thật sự được apply.
- Với Gatekeeper, thứ tự apply rất quan trọng: template trước, constraint sau.

### 2.2. `kubectl apply -f`

Được dùng trong lab:

```powershell
kubectl apply -f cloud/w10/day-a/policies/samples/valid-pod.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-privileged-pod.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-resources.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-latest-image.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-labels.yaml
```

Giải thích:

- `-f`: apply trực tiếp một file YAML.
- File `valid-pod.yaml` dùng để chứng minh manifest đúng được chấp nhận.
- Các file `invalid-*` dùng để chứng minh Gatekeeper reject manifest sai.

Vì sao cần học:

- Đây là cách test admission policy trực tiếp nhất.
- Output reject từ API server là evidence cho bài lab.

### 2.3. `kubectl auth can-i`

Được dùng trong lab:

```powershell
kubectl auth can-i create deployments -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i get secrets -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i delete namespaces --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i list pods -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i delete deployments -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i list nodes --as system:serviceaccount:platform-system:sre-sa
```

Giải thích:

- `auth can-i`: hỏi Kubernetes authorization layer xem một identity có được làm hành động không.
- `create deployments`: kiểm tra verb `create` trên resource `deployments`.
- `get secrets`: kiểm tra quyền đọc secret.
- `delete namespaces`: kiểm tra quyền xóa namespace cluster-level.
- `-n app-dev`: kiểm tra trong namespace `app-dev`.
- `--as system:serviceaccount:<namespace>:<serviceaccount>`: giả lập request đến từ ServiceAccount đó.

Vì sao cần học:

- RBAC phải được kiểm chứng bằng output `yes/no`, không kiểm tra bằng cảm giác.
- Đây là evidence chính cho yêu cầu 3 role: `developer`, `sre`, `viewer`.

### 2.4. `kubectl get`

Được dùng trong lab:

```powershell
kubectl get ns platform-system app-dev app-prod security
kubectl -n app-dev get sa developer-sa viewer-sa
kubectl -n platform-system get sa sre-sa
kubectl -n app-dev get role,rolebinding
kubectl get clusterrole w10-sre
kubectl get clusterrolebinding w10-sre
kubectl get constrainttemplates
kubectl get constraints
kubectl -n gatekeeper-system get pods
kubectl get crd
```

Giải thích:

- `get`: xem resource đã tồn tại chưa.
- `ns`: Namespace.
- `sa`: ServiceAccount.
- `role`, `rolebinding`, `clusterrole`, `clusterrolebinding`: resource RBAC.
- `constrainttemplates`, `constraints`: resource Gatekeeper.
- `crd`: CustomResourceDefinition.
- `-n <namespace>`: chỉ định namespace cần xem.

Vì sao cần học:

- Sau khi apply, phải kiểm tra resource thật sự đã được tạo.
- Với Gatekeeper, phải kiểm tra CRD và controller pod trước khi apply constraint.

### 2.5. `helm repo add`, `helm repo update`, `helm upgrade --install`

Được dùng để cài Gatekeeper:

```powershell
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm upgrade --install gatekeeper gatekeeper/gatekeeper `
  --namespace gatekeeper-system `
  --create-namespace
```

Giải thích:

- `helm repo add`: thêm Helm chart repository.
- `helm repo update`: cập nhật danh sách chart.
- `helm upgrade --install`: nếu release chưa có thì install, nếu đã có thì upgrade.
- `gatekeeper`: tên Helm release.
- `gatekeeper/gatekeeper`: chart Gatekeeper trong repo Helm.
- `--namespace gatekeeper-system`: cài vào namespace `gatekeeper-system`.
- `--create-namespace`: tự tạo namespace nếu chưa có.

Vì sao cần học:

- Gatekeeper là controller ngoài Kubernetes core, nên cần cài trước khi apply policy.
- Gatekeeper tạo CRD và admission webhook để reject manifest sai.

### 2.6. `Select-String`

Được dùng trong README:

```powershell
kubectl get crd | Select-String gatekeeper
```

Giải thích:

- `Select-String` là PowerShell command để lọc dòng có text khớp.
- Ở đây dùng để lọc CRD liên quan Gatekeeper.

Vì sao cần học:

- Giúp kiểm tra nhanh Gatekeeper CRD đã được cài chưa.

### 2.7. `kubectl delete pod --ignore-not-found`

Được dùng để cleanup sample:

```powershell
kubectl -n app-dev delete pod valid-w10-pod --ignore-not-found
```

Giải thích:

- `delete pod`: xóa pod test.
- `--ignore-not-found`: nếu pod không tồn tại thì không báo lỗi.

Vì sao cần học:

- Lab có sample pod hợp lệ để test policy, sau test nên dọn lại.

## 3. Field YAML chung cần hiểu

Các file YAML trong lab đều dùng cấu trúc Kubernetes cơ bản:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-dev
  labels:
    environment: dev
```

### 3.1. `apiVersion`

Dùng để chỉ API group và version của resource.

Ví dụ trong lab:

- `v1`: Namespace, ServiceAccount, Pod.
- `rbac.authorization.k8s.io/v1`: Role, RoleBinding, ClusterRole, ClusterRoleBinding.
- `apps/v1`: Deployment sample.
- `templates.gatekeeper.sh/v1`: ConstraintTemplate.
- `constraints.gatekeeper.sh/v1beta1`: Constraint.

Vì sao cần học:

- Kubernetes dùng `apiVersion` để biết resource thuộc API nào.
- Sai `apiVersion` thì `kubectl apply` có thể fail hoặc resource không đúng schema.

### 3.2. `kind`

Dùng để chỉ loại resource.

Ví dụ trong lab:

- `Namespace`
- `ServiceAccount`
- `Role`
- `RoleBinding`
- `ClusterRole`
- `ClusterRoleBinding`
- `Pod`
- `Deployment`
- `ConstraintTemplate`

Vì sao cần học:

- `kind` quyết định schema và hành vi của resource.
- RBAC, workload và Gatekeeper policy là các loại resource khác nhau.

### 3.3. `metadata.name`

Tên resource trong cluster.

Ví dụ:

- Namespace `app-dev`.
- ServiceAccount `developer-sa`.
- Role `developer`.
- ClusterRole `w10-sre`.

Vì sao cần học:

- Các resource khác sẽ tham chiếu tới tên này, ví dụ `roleRef.name` hoặc `subjects.name`.

### 3.4. `metadata.namespace`

Namespace nơi resource được tạo.

Ví dụ:

```yaml
metadata:
  name: developer-sa
  namespace: app-dev
```

Vì sao cần học:

- `Role`, `RoleBinding`, `ServiceAccount`, `Pod` là namespace-scoped.
- `ClusterRole` và `ClusterRoleBinding` không có namespace vì là cluster-scoped.

### 3.5. `metadata.labels`

Key-value metadata dùng để phân loại, ownership và policy.

Lab dùng:

- `owner`
- `app.kubernetes.io/name`
- `app.kubernetes.io/part-of`
- `environment`

Vì sao cần học:

- Gatekeeper policy yêu cầu workload có label ownership.
- Label giúp truy vết owner, cost, alert và incident response.

## 4. RBAC field cần hiểu

### 4.1. `rules`

Nằm trong `Role` hoặc `ClusterRole`.

Ví dụ:

```yaml
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Giải thích:

- `rules`: danh sách quyền.
- Mỗi rule nói rõ API group nào, resource nào, hành động nào được phép.

### 4.2. `apiGroups`

API group của resource.

Lab dùng:

- `[""]`: core API group, ví dụ `pods`, `services`, `configmaps`, `events`, `nodes`, `namespaces`.
- `["apps"]`: workload API group, ví dụ `deployments`, `replicasets`, `statefulsets`, `daemonsets`.
- `["batch"]`: job API group, ví dụ `jobs`, `cronjobs`.
- `["templates.gatekeeper.sh"]`: Gatekeeper ConstraintTemplate.
- `["constraints.gatekeeper.sh"]`: Gatekeeper Constraint.

Vì sao cần học:

- Cùng một resource name có thể thuộc API group khác nhau.
- RBAC rule phải khai báo đúng `apiGroups` thì quyền mới có hiệu lực.

### 4.3. `resources`

Resource mà rule áp dụng.

Ví dụ lab dùng:

- `pods`
- `pods/log`
- `services`
- `configmaps`
- `events`
- `deployments`
- `replicasets`
- `jobs`
- `cronjobs`
- `nodes`
- `namespaces`

Giải thích:

- `pods/log` là subresource dùng để đọc log pod.
- `nodes` và `namespaces` là cluster-level resource.

### 4.4. `verbs`

Hành động được phép.

Lab dùng:

- `get`: đọc một object.
- `list`: liệt kê nhiều object.
- `watch`: theo dõi thay đổi.
- `create`: tạo object.
- `update`: thay toàn bộ object.
- `patch`: sửa một phần object.
- `delete`: xóa object.

Vì sao cần học:

- Viewer chỉ nên có `get`, `list`, `watch`.
- Developer có thêm quyền ghi trong `app-dev`.
- SRE có quyền rộng hơn nhưng vẫn không dùng `cluster-admin`.

### 4.5. `subjects`

Nằm trong `RoleBinding` hoặc `ClusterRoleBinding`.

Ví dụ:

```yaml
subjects:
  - kind: ServiceAccount
    name: developer-sa
    namespace: app-dev
```

Giải thích:

- `kind`: loại identity được bind.
- `name`: tên identity.
- `namespace`: namespace của ServiceAccount.

Vì sao cần học:

- Role không tự cấp quyền cho ai.
- Binding mới là nơi gắn quyền với identity.

### 4.6. `roleRef`

Nằm trong `RoleBinding` hoặc `ClusterRoleBinding`.

Ví dụ:

```yaml
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
```

Giải thích:

- `apiGroup`: API group của RBAC.
- `kind`: bind tới `Role` hay `ClusterRole`.
- `name`: tên role được bind.

Vì sao cần học:

- `subjects` nói ai nhận quyền.
- `roleRef` nói nhận quyền nào.

## 5. Kustomize field cần hiểu

Lab dùng `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces.yaml
  - serviceaccounts.yaml
```

Giải thích:

- `kind: Kustomization`: khai báo thư mục này là một Kustomize package.
- `resources`: danh sách file hoặc thư mục con cần render/apply.

Vì sao cần học:

- Day A không apply từng YAML một cho RBAC, mà apply cả folder.
- `kubectl apply -k` đọc field `resources` để biết cần gửi resource nào lên cluster.

## 6. Gatekeeper field cần hiểu

### 6.1. `ConstraintTemplate`

File ví dụ:

```text
policies/constrainttemplates/required-labels.yaml
```

Các field chính:

- `apiVersion: templates.gatekeeper.sh/v1`: API cho ConstraintTemplate.
- `kind: ConstraintTemplate`: định nghĩa loại policy custom.
- `metadata.name`: tên template, ví dụ `k8srequiredw10labels`.
- `spec.crd.spec.names.kind`: tên kind mới mà template tạo ra, ví dụ `K8sRequiredW10Labels`.
- `spec.crd.spec.validation.openAPIV3Schema`: schema cho parameter của constraint.
- `spec.targets`: nơi khai báo Rego chạy trong admission.
- `target: admission.k8s.gatekeeper.sh`: policy chạy ở Kubernetes admission.
- `rego`: logic policy.

Vì sao cần học:

- ConstraintTemplate tạo CRD cho constraint custom.
- Nếu template chưa apply, constraint tương ứng chưa tồn tại trong Kubernetes API.

### 6.2. `Constraint`

File ví dụ:

```text
policies/constraints/required-labels.yaml
```

Các field chính:

- `apiVersion: constraints.gatekeeper.sh/v1beta1`: API cho constraint instance.
- `kind: K8sRequiredW10Labels`: kind được tạo bởi template.
- `metadata.name`: tên constraint.
- `spec.enforcementAction: deny`: reject request sai policy.
- `spec.match.excludedNamespaces`: namespace không áp dụng policy.
- `spec.match.kinds`: loại resource policy áp dụng.
- `spec.parameters`: tham số truyền vào Rego, ví dụ danh sách label bắt buộc.

Vì sao cần học:

- Template định nghĩa logic.
- Constraint quyết định logic đó áp dụng ở đâu và ở chế độ nào.

### 6.3. `enforcementAction`

Lab dùng:

```yaml
enforcementAction: deny
```

Giải thích:

- `deny`: request sai policy bị reject.

Vì sao cần học:

- W10 yêu cầu cluster-level enforcement, nên Day A không dừng ở audit.

### 6.4. `match.excludedNamespaces`

Lab exclude:

```yaml
excludedNamespaces:
  - kube-system
  - gatekeeper-system
  - argocd
  - monitoring
  - external-secrets
  - kyverno
```

Giải thích:

- Không áp policy lên namespace hệ thống.

Vì sao cần học:

- Chart/controller hệ thống có thể có manifest đặc thù.
- Nếu policy match quá rộng, có thể làm hỏng control plane/addon.

### 6.5. `match.kinds`

Ví dụ:

```yaml
kinds:
  - apiGroups: [""]
    kinds: ["Pod"]
```

Giải thích:

- Chỉ áp policy lên resource matching API group và kind.
- Pod security policy trong lab áp lên `Pod`.
- Required label policy áp lên `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`.

## 7. Rego biến và hàm cần hiểu

Lab dùng Rego trong `ConstraintTemplate`.

### 7.1. `package`

Ví dụ:

```rego
package k8srequiredw10labels
```

Giải thích:

- Tên namespace logic trong Rego.
- Mỗi template dùng một package riêng.

### 7.2. `input.review.object`

Ví dụ:

```rego
input.review.object.metadata.labels
input.review.object.spec.containers[_]
```

Giải thích:

- `input` là dữ liệu Gatekeeper đưa vào policy.
- `review.object` là Kubernetes object đang được admission kiểm tra.
- `metadata.labels` là labels của object.
- `spec.containers[_]` lặp qua từng container.

Vì sao cần học:

- Muốn biết Rego đang kiểm tra gì thì phải hiểu object đầu vào.

### 7.3. `input.parameters`

Ví dụ:

```rego
input.parameters.labels[_]
```

Giải thích:

- Tham số lấy từ `spec.parameters` trong Constraint.
- Trong required labels policy, đây là danh sách label bắt buộc.

### 7.4. `violation`

Ví dụ:

```rego
violation[{"msg": msg}] {
  ...
}
```

Giải thích:

- Nếu rule `violation` tạo output, Gatekeeper coi object là vi phạm.
- `msg` là thông báo reject.

### 7.5. Hàm Rego đang dùng

Lab dùng:

- `contains(image, ":")`: kiểm tra image có dấu `:` hay không.
- `endswith(image, ":latest")`: kiểm tra image dùng tag `latest`.
- `count(missing) > 0`: kiểm tra còn label thiếu.
- `sprintf(...)`: tạo message lỗi.
- `not`: phủ định điều kiện.

Vì sao cần học:

- Đây là những hàm đủ để hiểu toàn bộ Gatekeeper policy Day A.

## 8. Pod sample field cần hiểu

### 8.1. `spec.securityContext.runAsNonRoot`

Ví dụ:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
```

Giải thích:

- Yêu cầu container chạy bằng non-root user.

Vì sao cần học:

- Constraint `require-run-as-non-root` kiểm tra field này hoặc field tương ứng ở container.

### 8.2. `containers[].securityContext.privileged`

Ví dụ sai:

```yaml
securityContext:
  privileged: true
```

Giải thích:

- Cho container quyền privileged gần host-level.

Vì sao cần học:

- Constraint `disallow-privileged-containers` reject field này khi bằng `true`.

### 8.3. `allowPrivilegeEscalation`

Lab dùng trong pod hợp lệ:

```yaml
allowPrivilegeEscalation: false
```

Giải thích:

- Chặn process trong container leo thang quyền qua cơ chế như setuid.

Vì sao cần học:

- Đây là hardening tốt cho pod.
- Hiện lab chưa enforce field này bằng Gatekeeper, nhưng sample hợp lệ khai báo để thể hiện baseline an toàn.

### 8.4. `readOnlyRootFilesystem`

Lab dùng:

```yaml
readOnlyRootFilesystem: true
```

Giải thích:

- Root filesystem của container chỉ đọc.

Vì sao cần học:

- Giảm khả năng attacker ghi file vào container sau khi exploit.
- Field này có trong sample hợp lệ, nhưng lab chưa enforce bằng constraint.

### 8.5. `capabilities.drop`

Lab dùng:

```yaml
capabilities:
  drop: ["ALL"]
```

Giải thích:

- Bỏ toàn bộ Linux capabilities mặc định của container.

Vì sao cần học:

- Giảm quyền runtime của container.
- Field này có trong sample hợp lệ, nhưng lab chưa enforce bằng constraint.

### 8.6. `resources.requests` và `resources.limits`

Lab dùng:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Giải thích:

- `requests.cpu`: CPU scheduler dùng để đặt pod.
- `requests.memory`: memory scheduler dùng để đặt pod.
- `limits.cpu`: trần CPU runtime.
- `limits.memory`: trần memory runtime.
- `100m`: 0.1 CPU core.
- `128Mi`: 128 mebibytes memory.

Vì sao cần học:

- Constraint `require-container-requests-limits` reject container thiếu các field này.
- Day C dùng quota/limitrange dựa trên cùng khái niệm.

### 8.7. `image`

Lab dùng:

```yaml
image: nginx:1.27-alpine
image: nginx:latest
```

Giải thích:

- `nginx:1.27-alpine` có tag cụ thể.
- `nginx:latest` là tag mutable và bị reject.

Vì sao cần học:

- Constraint `disallow-latest-image-tag` chặn image thiếu tag hoặc dùng `latest`.
- Day B supply chain cần image tag/digest rõ ràng để scan/sign/verify.

## 9. Deployment sample field cần hiểu

File:

```text
policies/samples/invalid-missing-labels.yaml
```

Các field chính:

- `apiVersion: apps/v1`: Deployment thuộc API group `apps`.
- `kind: Deployment`: workload controller.
- `spec.replicas`: số pod mong muốn.
- `spec.selector.matchLabels`: selector để Deployment quản lý pod.
- `spec.template.metadata.labels`: label của pod template.
- `spec.template.spec.containers`: container chạy trong pod.

Vì sao cần học:

- Required labels constraint match `Deployment`.
- File này cố tình thiếu label ownership ở `metadata.labels` của Deployment để bị reject.

## 10. Những gì lab dùng và bạn phải giải thích được

Sau Day A, bạn phải giải thích được:

- Vì sao `developer` dùng `Role` namespace-level.
- Vì sao `sre` dùng `ClusterRole` nhưng không dùng `cluster-admin`.
- Vì sao `viewer` chỉ có `get/list/watch`.
- `apiGroups`, `resources`, `verbs` trong RBAC nghĩa là gì.
- `subjects` và `roleRef` gắn quyền cho ServiceAccount như thế nào.
- `kubectl auth can-i` kiểm tra RBAC ra sao.
- Vì sao Gatekeeper phải cài trước policy.
- Vì sao `ConstraintTemplate` phải apply trước `Constraint`.
- `enforcementAction: deny` làm gì.
- `excludedNamespaces` dùng để tránh chặn namespace hệ thống như thế nào.
- Rego `input.review.object` và `input.parameters` lấy dữ liệu từ đâu.
- Vì sao privileged, root user, thiếu request/limit và image `latest` là rủi ro.

Nếu giải thích được các mục trên, bạn có đủ nền để làm phần Day A của W10 và nối sang Day B/Day C.
