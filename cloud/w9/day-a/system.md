# Day A - System Design: GitOps và CI/CD

## 1. Mục tiêu của Day A

Mục tiêu của Day A là chuyển cách vận hành app từ thao tác thủ công bằng `kubectl apply` sang GitOps.

Trước Day A, trạng thái lab chủ yếu là:

- Manifest Kubernetes nằm trong repo.
- Người vận hành tự chạy `kubectl apply`.
- Cluster chạy được app, nhưng Git chưa phải nguồn điều khiển duy nhất.
- Nếu ai sửa trực tiếp trên cluster, repo không tự biết.
- Nếu repo đổi, cluster không tự cập nhật.

Vì vậy mục tiêu hệ thống là:

- Git phải trở thành source of truth.
- Cluster phải tự đồng bộ theo Git.
- Thay đổi phải đi qua commit/push thay vì apply tay.
- Có cơ chế tự phát hiện drift và kéo cluster về đúng state trong Git.
- Có CI tối thiểu để validate manifest trước khi merge/push.
- Có cấu trúc repo đủ rõ để Day B observability và Day C canary dùng tiếp.

Luồng mong muốn:

```text
Developer edit manifest
  -> git commit
  -> git push
  -> GitHub Actions validate
  -> Argo CD fetch repo
  -> Argo CD render manifest
  -> Argo CD sync Kubernetes cluster
```

## 2. Quyết định kiến trúc chính: dùng GitOps pull-based

### Vì sao không tiếp tục dùng `kubectl apply` thủ công

`kubectl apply` thủ công phù hợp khi học Kubernetes căn bản, nhưng không phù hợp cho mục tiêu W9 vì:

- Không có audit trail đầy đủ nếu người vận hành apply từ file local chưa commit.
- Dễ xảy ra drift giữa Git và cluster.
- Khó rollback đúng chuẩn vì rollback live cluster có thể bị ghi đè bởi manifest cũ.
- Không tạo được nền tốt cho progressive delivery ở Day C.

Với GitOps, mọi thay đổi quan trọng phải nằm trong Git trước. Cluster chỉ là trạng thái được reconcile từ Git.

### Vì sao chọn Argo CD

Tôi chọn Argo CD cho Day A vì nó phù hợp nhất với mục tiêu lab:

- Có UI rõ để nhìn app `Synced`, `OutOfSync`, `Healthy`, `Degraded`.
- Có controller chạy trong cluster và tự reconcile state.
- Hỗ trợ `Application`, `AppProject`, app-of-apps.
- Hỗ trợ automated sync, prune, self-heal.
- Dễ nối tiếp sang Argo Rollouts ở Day C vì cùng hệ sinh thái Argo.

Flux cũng là GitOps tốt, nhưng trong lab này Argo CD trực quan hơn cho việc demo và giải thích.

## 3. Quyết định tổ chức repo: app-of-apps

Day A dùng pattern app-of-apps.

Root app:

- File: `cloud/w9/day-a/argocd/root-app.yaml`
- Tên app: `w9-root`
- Namespace chạy Argo CD: `argocd`
- Source path: `cloud/w9/day-a/argocd/apps`

Root app không trực tiếp deploy workload. Nó deploy các child `Application`.

Child apps hiện có:

- `demo-web`: quản lý workload app chính trong namespace `lab`.
- `observability`: quản lý bundle Day B trong namespace `observability`.

Lý do dùng app-of-apps:

- Một điểm bootstrap duy nhất là `w9-root`.
- Khi cần thêm Day C hoặc lab khác, chỉ cần thêm child app.
- Người vận hành nhìn Argo CD UI sẽ thấy từng app riêng, dễ debug.
- Thứ tự sync có thể điều khiển bằng sync wave.

## 4. Quyết định phân vùng bằng AppProject

File:

- `cloud/w9/day-a/argocd/project.yaml`

AppProject tên:

- `w9-platform`

Mục tiêu của `AppProject` là gom các app W9 vào cùng một phạm vi quản trị.

Các destination được bật:

- `argocd`: để root app tạo child `Application`.
- `lab`: để deploy workload `demo-web`.
- `observability`: để deploy Day B observability.

Setting đặc biệt:

```yaml
sourceRepos:
  - "*"
```

Trong lab, setting này giúp giảm ma sát khi học vì Argo CD được phép đọc repo đang dùng. Trong production nên giới hạn lại đúng repo được phép.

Setting đặc biệt:

```yaml
clusterResourceWhitelist:
  - group: "*"
    kind: "*"
```

Trong lab, setting này cho phép apply các custom resource như `ServiceMonitor`, `PrometheusRule`, hoặc các resource mở rộng khác. Trong production nên giới hạn theo loại resource thật sự cần.

## 5. Quyết định sync: automated, prune, selfHeal

Trong `root-app.yaml`, `demo-web.yaml`, `observability.yaml`, tôi bật:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

### Vì sao bật `automated`

Mục tiêu là Git push xong thì cluster tự cập nhật. Nếu không bật automated sync, Argo CD chỉ báo `OutOfSync`, người vận hành vẫn phải bấm Sync hoặc chạy CLI.

### Vì sao bật `prune`

`prune: true` giúp xóa resource khỏi cluster nếu resource đó đã bị xóa khỏi Git.

Nếu không bật prune:

- Manifest đã xóa trong Git.
- Resource cũ vẫn nằm trong cluster.
- Cluster vẫn còn trạng thái rác, gây khó debug.

### Vì sao bật `selfHeal`

`selfHeal: true` giúp Argo CD sửa drift nếu ai đó sửa resource trực tiếp trong cluster.

Ví dụ:

- Ai đó sửa image của `demo-web` bằng `kubectl edit`.
- Git vẫn nói image phải là `demo-web-metrics:local`.
- Argo CD sẽ kéo resource quay lại đúng Git.

Đây là điểm quan trọng để chứng minh Git là source of truth.

### Vì sao bật `CreateNamespace=true`

App `demo-web` deploy vào namespace `lab`, app `observability` deploy vào namespace `observability`.

`CreateNamespace=true` giúp Argo CD tạo namespace nếu chưa tồn tại. Tuy vậy repo vẫn có manifest namespace riêng để metadata/labels được quản lý rõ.

## 6. Quyết định thứ tự sync bằng sync wave

Child app `demo-web` có:

```yaml
argocd.argoproj.io/sync-wave: "10"
```

Child app `observability` có:

```yaml
argocd.argoproj.io/sync-wave: "20"
```

Ý nghĩa:

- `demo-web` được sync trước.
- `observability` được sync sau.

Lý do:

- Observability cần scrape app.
- Nếu observability sync trước app thì `ServiceMonitor` vẫn tồn tại được, nhưng dashboard/rule chưa có dữ liệu.
- Sync wave giúp câu chuyện hệ thống rõ hơn: app nền trước, quan sát sau.

## 7. Quyết định manifest app: Kustomize base và overlay

App `demo-web` nằm ở:

```text
cloud/w9/day-a/manifests/demo-web/
```

Cấu trúc:

```text
base/
  namespace.yaml
  deployment.yaml
  service.yaml
  kustomization.yaml
overlays/minikube/
  patch-deployment.yaml
  kustomization.yaml
```

Vì sao dùng Kustomize:

- Kubernetes native, `kubectl kustomize` chạy được không cần Helm.
- Tách được phần chung và phần môi trường.
- Dễ render trong GitHub Actions.
- Phù hợp lab nhỏ hơn Helm.

Base chứa cấu hình app chính:

- Namespace `lab`.
- Deployment `demo-web`.
- Service `demo-web`.

Overlay `minikube` thêm các biến liên quan observability:

```yaml
OTEL_SERVICE_NAME=demo-web
OTEL_RESOURCE_ATTRIBUTES=service.namespace=lab,deployment.environment=minikube
```

Các biến này không tự instrument app, nhưng giúp giữ naming nhất quán khi app có telemetry hoặc khi cần mở rộng.

## 8. Quyết định app image trong Day A

Ban đầu W8 dùng nginx. Sang W9, app được đổi sang image:

```yaml
image: demo-web-metrics:local
```

Lý do:

- Day B cần metric thật để Prometheus scrape.
- Nginx mặc định không tự expose metric application-level ở `/metrics`.
- App mới vẫn đơn giản, nhưng có endpoint `/`, `/healthz`, `/metrics`, `/slow`, `/error`.

Setting đặc biệt:

```yaml
imagePullPolicy: IfNotPresent
```

Lý do:

- Image được build local vào minikube.
- Không có registry remote cho tag `demo-web-metrics:local`.
- Nếu dùng `Always`, Kubernetes có thể cố pull từ registry và fail.

Probe:

```yaml
readinessProbe: /healthz
livenessProbe: /healthz
```

Lý do:

- `/healthz` là endpoint nhẹ, không phụ thuộc metric.
- Readiness kiểm soát pod có được đưa vào service hay không.
- Liveness kiểm soát restart nếu app chết.

## 9. Quyết định CI: GitHub Actions validate render

Workflow:

```text
.github/workflows/w9-gitops-validate.yml
```

Mục tiêu workflow:

- Render Kustomize của `demo-web`.
- Render bundle Day B.
- Parse YAML để bắt lỗi cú pháp sớm.
- Upload rendered manifest khi push vào `main`.

Vì sao không dùng `kubectl apply --dry-run=client` cho tất cả:

- Repo có CRD như `Application`, `PrometheusRule`, `ServiceMonitor`.
- GitHub runner không có cluster đang cài CRD đó.
- Dry-run client có thể fail giả vì không biết custom kind.

Vì vậy workflow dùng:

- `kubectl kustomize` để render.
- Python `pyyaml` để parse YAML.

Đây là validate mức repo, không thay thế validate runtime trong cluster.

## 10. Từ trạng thái chưa có gì đến Day A chạy được

Điểm khởi đầu:

- Có cluster Kubernetes/minikube.
- Có repo GitHub.
- Có manifest app trong repo.
- Chưa có GitOps controller.

Các bước hệ thống:

1. Cài Argo CD vào namespace `argocd`.
2. Apply `AppProject` `w9-platform`.
3. Apply root app `w9-root`.
4. Argo CD đọc repo `Remmusss-aws-accelerator-p2`, branch `main`.
5. Argo CD đọc path `cloud/w9/day-a/argocd/apps`.
6. Root app tạo child app `demo-web` và `observability`.
7. Child app `demo-web` render Kustomize path `cloud/w9/day-a/manifests/demo-web/overlays/minikube`.
8. Argo CD apply namespace, deployment, service vào `lab`.
9. Nếu Git thay đổi, Argo CD reconcile lại.

Kết quả Day A:

- App chạy ở namespace `lab`.
- Argo CD chạy ở namespace `argocd`.
- GitHub là source of truth.
- Day B và Day C có nền để nối tiếp.
