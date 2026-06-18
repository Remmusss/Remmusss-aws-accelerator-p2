# W10 Day A - RBAC + Admission Policy

## 1. Mục tiêu cần đạt được

Day A xây dựng nền tảng kiểm soát quyền và kiểm soát cấu hình ở cấp Kubernetes API. Kết quả cuối ngày không chỉ là có vài manifest RBAC, mà là chứng minh cluster không còn phụ thuộc vào việc developer tự hứa sẽ làm đúng.

Sau khi hoàn thành, hệ thống cần đạt các mục tiêu:

- Có 3 vai trò rõ ràng: `developer`, `sre`, `viewer`.
- Mỗi vai trò được gắn với ServiceAccount để kiểm tra bằng `kubectl auth can-i`.
- Developer chỉ được thao tác trong namespace ứng dụng được cấp, không được sửa resource cluster-level.
- Viewer chỉ được đọc, không được tạo/sửa/xóa workload hoặc secret.
- SRE có quyền vận hành rộng hơn developer, nhưng không dùng `cluster-admin` mặc định.
- Có admission policy chặn cấu hình rủi ro ngay khi resource được apply.
- Có ít nhất 4 Gatekeeper constraint ở trạng thái enforce.
- Có sample manifest pass/fail để kiểm thử từng policy.
- Có evidence ghi lại kết quả RBAC và admission reject.

Trọng tâm của ngày này là chuyển từ "quyền theo cảm tính" sang "quyền và policy được khai báo, kiểm thử, version trong Git".

## 2. Cần làm những gì

### 2.1. Cấu trúc thư mục

Day A được tổ chức như sau:

```text
cloud/w10/day-a/
  .gitignore
  kustomization.yaml
  learning-guide.md
  system.md
  rbac/
    namespaces.yaml
    serviceaccounts.yaml
    roles.yaml
    rolebindings.yaml
    clusterroles.yaml
    clusterrolebindings.yaml
    kustomization.yaml
  policies/
    gatekeeper-install.md
    kustomization.yaml
    constrainttemplates/
    constraints/
    samples/
  evidence/
    rbac-can-i.md
    gatekeeper-policy-tests.md
```

Lý do tách như vậy:

- `rbac/` quản lý quyền truy cập.
- `policies/` quản lý admission guardrail.
- `samples/` chứa manifest đúng/sai để test policy.
- `evidence/` lưu checklist và output khi thực hành.
- `.gitignore` chặn log/output local không cần commit.

### 2.2. Namespace và identity

Day A tạo các namespace:

- `platform-system`: chứa ServiceAccount hoặc thành phần vận hành platform.
- `app-dev`: namespace developer dùng để deploy workload.
- `app-prod`: mô phỏng production, dùng cho các bài test mở rộng.
- `security`: namespace dành cho tài nguyên security/policy nếu cần tách riêng.

ServiceAccount:

- `developer-sa` trong `app-dev`.
- `viewer-sa` trong `app-dev`.
- `sre-sa` trong `platform-system`.

Lý do dùng ServiceAccount:

- Dễ kiểm thử bằng `kubectl auth can-i --as system:serviceaccount:...`.
- Không cần tích hợp IAM/OIDC thật trong lab.
- Vẫn mô phỏng đúng nguyên tắc identity trong Kubernetes.

## 3. RBAC cần triển khai

### 3.1. Quyền `developer`

`developer` là `Role` trong namespace `app-dev`, không phải quyền toàn cluster.

Developer được:

- `get`, `list`, `watch` pod, pod log, service, configmap, event.
- `create`, `update`, `patch`, `delete` service và configmap.
- `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` deployment/replicaset.
- `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` job/cronjob.

Developer không được:

- Đọc hoặc sửa `secrets`.
- Sửa `roles`, `rolebindings`, `clusterroles`, `clusterrolebindings`.
- Thao tác `nodes`, `namespaces`, `persistentvolumes`.

Lý do:

- Developer cần deploy và debug app trong namespace của mình.
- Secret là dữ liệu nhạy cảm, không cấp quyền đọc mặc định.
- RBAC resource không được để developer tự sửa vì có thể tự nâng quyền.
- Node và namespace là tài nguyên platform-level.

### 3.2. Quyền `viewer`

`viewer` là `Role` read-only trong `app-dev`.

Viewer được:

- `get`, `list`, `watch` pod, pod log, service, configmap, event.
- `get`, `list`, `watch` deployment, replicaset, statefulset, daemonset.
- `get`, `list`, `watch` job, cronjob.

Viewer không được:

- `create`, `update`, `patch`, `delete`.
- Đọc secret.

Lý do:

- Viewer dùng cho người cần quan sát hệ thống nhưng không vận hành.
- Không cấp quyền ghi để tránh thay đổi ngoài GitOps.
- Không đọc secret để tránh lộ credential.

### 3.3. Quyền `sre`

`sre` dùng `ClusterRole` tên `w10-sre`.

SRE được:

- Xem node, namespace, pod, pod log, service, endpoint, event, configmap toàn cluster.
- Xem workload thuộc `apps` và `batch`.
- Tạo/sửa template và constraint Gatekeeper để vận hành policy.

SRE không dùng `cluster-admin`.

Lý do:

- SRE cần quan sát cross-namespace để điều tra sự cố.
- Quyền policy cần thiết cho người vận hành security guardrail.
- `cluster-admin` quá rộng, khó audit và không phù hợp nguyên tắc least privilege.

### 3.4. Kiểm thử RBAC

File evidence: `evidence/rbac-can-i.md`.

Các lệnh chính:

```powershell
kubectl auth can-i create deployments -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i get secrets -n app-dev --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i delete namespaces --as system:serviceaccount:app-dev:developer-sa
kubectl auth can-i list pods -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i delete deployments -n app-dev --as system:serviceaccount:app-dev:viewer-sa
kubectl auth can-i list nodes --as system:serviceaccount:platform-system:sre-sa
```

Kết quả mong muốn:

- Developer tạo deployment trong `app-dev`: `yes`.
- Developer đọc secret: `no`.
- Developer xóa namespace: `no`.
- Viewer list pod: `yes`.
- Viewer delete deployment: `no`.
- SRE list node: `yes`.

## 4. Admission Policy cần triển khai

### 4.1. Công nghệ chọn: OPA Gatekeeper

Day A dùng OPA Gatekeeper cho admission policy.

Lý do chọn Gatekeeper:

- Dùng OPA/Rego, đúng scope học của W10.
- Có mô hình `ConstraintTemplate` và `Constraint` rõ ràng.
- Hỗ trợ audit existing resource và deny resource mới.
- Policy được version trong Git.
- Dễ chứng minh cluster-level enforcement.

ValidatingAdmissionPolicy native của Kubernetes 1.30+ vẫn cần đọc để so sánh, nhưng Day A dùng Gatekeeper làm công cụ chính vì phù hợp bài lab OPA/Gatekeeper và dễ demo hơn trong nhiều môi trường cluster.

### 4.2. Constraint 1: bắt buộc label ownership

File:

- `policies/constrainttemplates/required-labels.yaml`
- `policies/constraints/required-labels.yaml`

Policy yêu cầu workload có:

- `owner`
- `app.kubernetes.io/name`
- `app.kubernetes.io/part-of`

Áp dụng cho:

- `Deployment`
- `StatefulSet`
- `DaemonSet`
- `Job`
- `CronJob`

Lý do:

- Label ownership giúp biết ai chịu trách nhiệm workload.
- Cần cho incident response, alert routing và cost attribution.
- W10 Day C cũng dùng ownership cho runbook và cost guard.

### 4.3. Constraint 2: cấm privileged container

File:

- `policies/constrainttemplates/disallow-privileged.yaml`
- `policies/constraints/disallow-privileged.yaml`

Policy chặn pod có:

```yaml
securityContext:
  privileged: true
```

Lý do:

- Privileged container có quyền gần host-level.
- Nếu container bị compromise, attacker có thể leo thang ra node.
- Đây là lỗi hardening cơ bản phải chặn ở admission.

### 4.4. Constraint 3: bắt buộc `runAsNonRoot`

File:

- `policies/constrainttemplates/require-non-root.yaml`
- `policies/constraints/require-non-root.yaml`

Policy yêu cầu pod hoặc container có:

```yaml
runAsNonRoot: true
```

Lý do:

- Chạy root trong container làm tăng tác hại khi app bị exploit.
- `runAsNonRoot` là baseline quan trọng trong Kubernetes Pod Security Standards.
- Admission policy đảm bảo lỗi bị chặn trước khi workload chạy.

### 4.5. Constraint 4: bắt buộc resource requests/limits

File:

- `policies/constrainttemplates/require-resources.yaml`
- `policies/constraints/require-resources.yaml`

Policy yêu cầu mỗi container có:

- `resources.requests.cpu`
- `resources.requests.memory`
- `resources.limits.cpu`
- `resources.limits.memory`

Lý do:

- Scheduler cần request để đặt pod đúng.
- Limit giảm rủi ro workload lỗi chiếm tài nguyên node.
- Đây là nền cho Day C `ResourceQuota` và `LimitRange`.

### 4.6. Constraint 5: cấm image tag `latest`

File:

- `policies/constrainttemplates/disallow-latest-tag.yaml`
- `policies/constraints/disallow-latest-tag.yaml`

Policy chặn:

- Image không có tag.
- Image dùng `:latest`.

Lý do:

- `latest` không immutable.
- GitOps cần trạng thái tái lập được.
- Day B supply chain cần image tag/digest rõ ràng để scan, sign và verify.

## 5. Cách apply

### 5.1. Apply RBAC

```powershell
kubectl apply -k cloud/w10/day-a/rbac
```

Hoặc dùng entrypoint Day A:

```powershell
kubectl apply -k cloud/w10/day-a
```

Top-level `kustomization.yaml` chỉ include RBAC để tránh apply Gatekeeper constraint trước khi CRD constraint được tạo.

### 5.2. Cài Gatekeeper

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

### 5.3. Apply Gatekeeper policy đúng thứ tự

Không apply template và constraint chung ở lần đầu, vì `ConstraintTemplate` tạo ra CRD cho loại `Constraint` tương ứng.

Apply theo thứ tự:

```powershell
kubectl apply -k cloud/w10/day-a/policies/constrainttemplates
kubectl apply -k cloud/w10/day-a/policies/constraints
```

Sau đó kiểm tra:

```powershell
kubectl get constrainttemplates
kubectl get constraints
```

## 6. Kiểm thử admission

File evidence: `evidence/gatekeeper-policy-tests.md`.

Manifest hợp lệ:

- `policies/samples/valid-pod.yaml`

Manifest không hợp lệ:

- `policies/samples/invalid-privileged-pod.yaml`
- `policies/samples/invalid-missing-resources.yaml`
- `policies/samples/invalid-latest-image.yaml`
- `policies/samples/invalid-missing-labels.yaml`

Lệnh test:

```powershell
kubectl apply -f cloud/w10/day-a/policies/samples/valid-pod.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-privileged-pod.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-resources.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-latest-image.yaml
kubectl apply -f cloud/w10/day-a/policies/samples/invalid-missing-labels.yaml
```

Kết quả mong muốn:

- `valid-pod.yaml` apply thành công.
- Manifest privileged bị reject.
- Manifest thiếu resource request/limit bị reject.
- Manifest dùng `latest` bị reject.
- Workload thiếu label ownership bị reject.

## 7. Artifact thực tế trong repo

Day A hiện có các file triển khai sau:

- `.gitignore`: chặn log/output local và rendered artifact.
- `rbac/namespaces.yaml`: tạo `platform-system`, `app-dev`, `app-prod`, `security`.
- `rbac/serviceaccounts.yaml`: tạo `developer-sa`, `viewer-sa`, `sre-sa`.
- `rbac/roles.yaml`: quyền namespace-level cho `developer` và `viewer`.
- `rbac/rolebindings.yaml`: gắn `developer-sa` và `viewer-sa` với Role tương ứng.
- `rbac/clusterroles.yaml`: quyền SRE cross-namespace không dùng `cluster-admin`.
- `rbac/clusterrolebindings.yaml`: gắn `sre-sa` với ClusterRole `w10-sre`.
- `policies/constrainttemplates/`: 5 Gatekeeper templates cho label, privileged, non-root, resources, image tag.
- `policies/constraints/`: 5 constraint `enforcementAction: deny`.
- `policies/samples/`: manifest hợp lệ và không hợp lệ để test admission.
- `evidence/`: checklist ghi lại output `kubectl auth can-i` và Gatekeeper reject.
- `kustomization.yaml`: entrypoint apply RBAC Day A; Gatekeeper templates và constraints apply riêng theo hai bước.

## 8. Tiêu chí hoàn thành

Day A hoàn thành khi:

- Có RBAC manifest cho `developer`, `sre`, `viewer`.
- Có test `kubectl auth can-i` chứng minh quyền đúng.
- Có ít nhất 4 Gatekeeper constraint enforce.
- Có sample pass/fail cho từng constraint.
- Không dùng `cluster-admin` làm cách giải quyết mặc định.
- Tài liệu giải thích rõ vì sao chọn Gatekeeper, vì sao chọn từng setting, và rủi ro được giảm là gì.

## 9. Các lệnh và thuộc tính bắt buộc phải giải thích được

Phần này đảm bảo `system.md` khớp với lab thực tế và `learning-guide.md`. Những mục dưới đây đều đang xuất hiện trong manifest hoặc lệnh chạy Day A.

### 9.1. Lệnh chạy

- `kubectl apply -k <folder>`: apply một thư mục Kustomize có `kustomization.yaml`.
- `kubectl apply -f <file>`: apply trực tiếp một file YAML, dùng cho sample valid/invalid.
- `kubectl auth can-i <verb> <resource> -n <namespace> --as <identity>`: kiểm tra RBAC cho một identity cụ thể.
- `kubectl get <resource>`: kiểm tra resource đã tồn tại chưa.
- `helm repo add`, `helm repo update`, `helm upgrade --install`: cài hoặc nâng cấp Gatekeeper bằng Helm.
- `kubectl get crd | Select-String gatekeeper`: lọc CRD liên quan Gatekeeper trong PowerShell.
- `kubectl delete pod --ignore-not-found`: dọn pod test mà không lỗi nếu pod đã không còn.

### 9.2. Field YAML chung

- `apiVersion`: API group/version của resource, ví dụ `v1`, `rbac.authorization.k8s.io/v1`, `templates.gatekeeper.sh/v1`.
- `kind`: loại resource, ví dụ `Namespace`, `ServiceAccount`, `Role`, `ConstraintTemplate`.
- `metadata.name`: tên resource.
- `metadata.namespace`: namespace của resource namespace-scoped.
- `metadata.labels`: metadata phục vụ ownership, policy match, cost và incident response.

### 9.3. Field RBAC

- `rules`: danh sách quyền trong `Role` hoặc `ClusterRole`.
- `apiGroups`: API group của resource. Lab dùng `""`, `apps`, `batch`, `templates.gatekeeper.sh`, `constraints.gatekeeper.sh`.
- `resources`: resource được cấp quyền, ví dụ `pods`, `pods/log`, `deployments`, `nodes`.
- `verbs`: hành động được phép, ví dụ `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`.
- `subjects`: identity nhận quyền trong `RoleBinding` hoặc `ClusterRoleBinding`.
- `roleRef`: Role hoặc ClusterRole được bind cho subject.

### 9.4. Field Gatekeeper

- `ConstraintTemplate`: định nghĩa loại policy custom và logic Rego.
- `spec.crd.spec.names.kind`: kind constraint mới được tạo từ template.
- `spec.crd.spec.validation.openAPIV3Schema`: schema tham số cho constraint.
- `spec.targets[].target: admission.k8s.gatekeeper.sh`: chạy policy ở admission.
- `spec.targets[].rego`: logic policy.
- `Constraint`: instance áp dụng template vào resource cụ thể.
- `spec.enforcementAction: deny`: reject request sai policy.
- `spec.match.excludedNamespaces`: namespace không áp dụng policy.
- `spec.match.kinds`: loại resource policy áp dụng.
- `spec.parameters`: tham số truyền vào Rego, ví dụ danh sách label bắt buộc.

### 9.5. Biến và hàm Rego

- `package`: namespace logic trong file Rego.
- `input.review.object`: Kubernetes object đang được admission kiểm tra.
- `input.parameters`: tham số lấy từ `spec.parameters` của Constraint.
- `violation[{"msg": msg}]`: output báo resource vi phạm policy.
- `contains`, `endswith`, `count`, `sprintf`, `not`: các hàm/toán tử Rego đang dùng trong template Day A.

### 9.6. Field pod/workload security

- `spec.securityContext.runAsNonRoot`: yêu cầu pod/container chạy non-root.
- `containers[].securityContext.privileged`: nếu `true` thì container có quyền privileged và bị reject.
- `allowPrivilegeEscalation: false`: chặn leo thang quyền trong container.
- `readOnlyRootFilesystem: true`: root filesystem chỉ đọc.
- `capabilities.drop: ["ALL"]`: bỏ Linux capabilities mặc định.
- `resources.requests.cpu`, `resources.requests.memory`: tài nguyên scheduler dùng để đặt pod.
- `resources.limits.cpu`, `resources.limits.memory`: trần tài nguyên runtime.
- `image`: image container; tag `latest` bị reject vì không immutable.

### 9.7. Field Deployment sample

- `spec.replicas`: số pod mong muốn.
- `spec.selector.matchLabels`: selector để Deployment quản lý pod.
- `spec.template.metadata.labels`: label của pod template.
- `spec.template.spec.containers`: container được tạo trong pod template.

File `invalid-missing-labels.yaml` cố tình thiếu label ownership ở `metadata.labels` của Deployment để chứng minh required-labels constraint reject workload thiếu ownership.
