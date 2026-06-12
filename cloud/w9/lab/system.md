# W9 Lab System Design

## 1. Mục Tiêu Hệ Thống

Lab này được thiết kế để mô phỏng một pipeline triển khai ứng dụng theo GitOps trên Kubernetes. Mục tiêu không chỉ là chạy được một app, mà là xây dựng đầy đủ vòng đời release:

- Khai báo toàn bộ trạng thái mong muốn trong Git.
- Dùng Argo CD để tự động đồng bộ manifest từ Git vào cluster.
- Chia hệ thống thành nhiều app nhỏ, có ownership rõ ràng.
- Dùng sync waves để kiểm soát thứ tự tạo resource.
- Dùng Argo Rollouts để triển khai canary thay vì update toàn bộ cùng lúc.
- Dùng Prometheus để đo chất lượng runtime bằng metric thật.
- Dùng AnalysisTemplate để tự động quyết định promote hoặc abort rollout.
- Dùng Alertmanager để gửi cảnh báo khi SLO bị vi phạm.
- Ẩn thông tin email và app password khỏi repo public bằng Secret được tạo từ `.env` local.

Điểm quan trọng của lab là: Git là source of truth, Kubernetes là nơi chạy workload, Argo CD là controller reconcile, Prometheus là nguồn dữ liệu đánh giá chất lượng, Argo Rollouts là controller release an toàn.

## 2. Kiến Trúc Tổng Thể

Hệ thống hiện tại gồm các nhóm thành phần chính:

- `argocd`: chạy Argo CD và các Argo CD Application.
- `demo`: chạy app web cơ bản và API canary.
- `demo-fe-be`: chạy app frontend/backend đơn giản.
- `monitoring`: chạy kube-prometheus-stack gồm Prometheus, Alertmanager, Grafana và Prometheus Operator.
- `argo-rollouts`: chạy controller và dashboard của Argo Rollouts.

Luồng hoạt động chính:

1. Người dùng sửa manifest trong repo.
2. Commit và push lên branch `main`.
3. Argo CD phát hiện revision mới trên repo remote.
4. Argo CD so sánh desired state trong Git với live state trong cluster.
5. Nếu lệch, Argo CD sync resource vào cluster.
6. Với API, Argo Rollouts tiếp quản quá trình rollout canary.
7. Prometheus scrape metric từ API thông qua ServiceMonitor.
8. AnalysisTemplate query Prometheus để quyết định canary có đạt success rate không.
9. Nếu success rate đạt ngưỡng, rollout tiếp tục promote.
10. Nếu success rate thấp, rollout bị abort.
11. PrometheusRule tạo alert khi SLO bị vi phạm.
12. Alertmanager route alert phù hợp tới email cá nhân thông qua Secret local.

## 3. Vì Sao Chọn GitOps

Lab chọn GitOps vì phù hợp với mục tiêu quản trị Kubernetes theo hướng khai báo, có audit trail và dễ rollback.

Nếu deploy thủ công bằng `kubectl apply`, trạng thái thật trong cluster dễ bị lệch và khó biết ai đã thay đổi gì. Với GitOps, mọi thay đổi hạ tầng/app phải đi qua Git, nên có lịch sử commit, review, diff và rollback rõ ràng.

Trong lab này, GitOps còn giúp chứng minh một nguyên tắc quan trọng: Argo CD không đọc file local trên máy. Nó chỉ đọc repo remote theo `repoURL`, `targetRevision` và `path`. Vì vậy nếu sửa manifest local mà chưa push, Argo CD sẽ không thấy update.

## 4. Argo CD App-of-Apps

### 4.1 Root Application

File root:

`cloud/w9/lab/argocd/root.yaml`

Root Application:

- Tên: `root`
- Namespace: `argocd`
- Repo: `https://github.com/Remmusss/Remmusss-aws-accelerator-p2.git`
- Branch: `main`
- Path: `cloud/w9/lab/argocd/apps`
- Destination namespace: `argocd`

Root app không trực tiếp chạy workload nghiệp vụ. Nó quản lý các Application con nằm trong `cloud/w9/lab/argocd/apps`.

Lý do dùng App-of-Apps:

- Bootstrap đơn giản: apply một app root là đủ.
- Tách ownership: mỗi app con có source path và namespace riêng.
- Dễ mở rộng: thêm app mới bằng cách thêm một Application YAML vào thư mục `apps`.
- Dễ quan sát: Argo CD UI hiển thị từng app con như `web`, `api`, `fe-be`, `kube-prometheus-stack`, `argo-rollouts`.

### 4.2 Setting Của Root App

Root app bật:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

`automated` được dùng vì lab muốn Argo CD tự reconcile khi Git đổi, không cần bấm sync thủ công mỗi lần.

`prune: true` cho phép Argo CD xóa resource khỏi cluster nếu resource đó đã bị xóa khỏi Git. Setting này quan trọng trong GitOps vì nếu không prune, resource cũ có thể vẫn tồn tại dù Git không còn khai báo.

`selfHeal: true` cho phép Argo CD sửa lại live state nếu ai đó sửa trực tiếp resource trong cluster. Đây là cơ chế chống drift giữa cluster và Git.

`CreateNamespace=true` cho phép tạo namespace đích nếu chưa có. Dù một số namespace đã được khai báo riêng trong manifest, setting này vẫn giúp giảm lỗi khi app đích cần namespace trước.

## 5. Các Argo CD Application Con

### 5.1 App `web`

File:

`cloud/w9/lab/argocd/apps/web.yaml`

App này trỏ tới:

`cloud/w9/lab/gitops/k8s`

Destination:

- Namespace: `demo`
- Cluster: `https://kubernetes.default.svc`

Mục tiêu của app `web` là minh họa GitOps cơ bản với Namespace, ConfigMap, Deployment và Service.

Setting:

- `automated.prune: true`
- `automated.selfHeal: true`
- `CreateNamespace=true`

Lý do chọn cấu hình này:

- App đơn giản nhưng vẫn cần tự sync khi Git đổi.
- `selfHeal` giúp demo việc nếu sửa replicas/image ngoài cluster thì Argo CD sẽ đưa về đúng Git.
- `prune` giúp resource cũ được dọn khi xóa khỏi manifest.

### 5.2 App `fe-be`

File:

`cloud/w9/lab/argocd/apps/fe-be.yaml`

App này trỏ tới:

`cloud/w9/lab/gitops/fe-be`

Destination:

- Namespace: `demo-fe-be`

Mục tiêu của app `fe-be` là minh họa một app có frontend và backend riêng, dùng Kustomize để generate ConfigMap từ file code/config thay vì nhúng trực tiếp nội dung vào YAML.

Lý do tách FE/BE:

- Gần với cấu trúc app thật hơn app `web`.
- Có dependency giữa frontend và backend.
- Có thể demo Service DNS nội bộ Kubernetes.
- Có thể demo sync waves và mount ConfigMap thành file.

### 5.3 App `api`

File:

`cloud/w9/lab/argocd/apps/api.yaml`

App này trỏ tới:

`cloud/w9/lab/gitops/k8s-api`

Destination:

- Namespace: `demo`

Mục tiêu của app `api` là chạy workload có canary rollout và metric-driven analysis.

Setting đặc biệt:

```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
```

`ServerSideApply=true` được bật vì app này dùng CRD như `Rollout`, `AnalysisTemplate`, `PrometheusRule`, `ServiceMonitor`. Server-side apply thường ổn định hơn cho resource lớn hoặc resource do controller mutate.

### 5.4 App `argo-rollouts`

File:

`cloud/w9/lab/argocd/apps/argo-rollouts.yaml`

App này cài Helm chart:

- Repo: `https://argoproj.github.io/argo-helm`
- Chart: `argo-rollouts`
- Version: `2.37.7`
- Namespace: `argo-rollouts`

Mục tiêu là cài controller xử lý `Rollout`, `AnalysisTemplate`, `AnalysisRun` và dashboard để quan sát rollout.

Setting Helm:

```yaml
dashboard:
  enabled: true
```

Dashboard được bật để dễ demo và quan sát trạng thái rollout bằng UI ngoài CLI.

Setting sync:

```yaml
syncOptions:
  - CreateNamespace=true
  - Replace=true
  - RespectIgnoreDifferences=true
```

`Replace=true` được dùng vì Helm chart có CRD. Với CRD, apply kiểu merge đôi khi gây lỗi hoặc OutOfSync khó xử lý khi schema thay đổi.

`RespectIgnoreDifferences=true` yêu cầu Argo CD tôn trọng phần `ignoreDifferences` khi sync.

`ignoreDifferences` được cấu hình cho CRD:

```yaml
ignoreDifferences:
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    jsonPointers:
      - /spec
      - /metadata/annotations/controller-gen.kubebuilder.io~1version
```

Lý do là CRD thường bị Kubernetes hoặc Helm/controller thay đổi một số field sau khi apply. Nếu không ignore, Argo CD có thể báo OutOfSync dù hệ thống hoạt động đúng.

### 5.5 App `kube-prometheus-stack`

File:

`cloud/w9/lab/argocd/apps/kube-prometheus-stack.yaml`

App này cài Helm chart:

- Repo: `https://prometheus-community.github.io/helm-charts`
- Chart: `kube-prometheus-stack`
- Version: `65.1.1`
- Namespace: `monitoring`

Mục tiêu là cung cấp Prometheus, Alertmanager, Grafana, Prometheus Operator và các CRD như `ServiceMonitor`, `PrometheusRule`.

Setting đặc biệt:

```yaml
alertmanager:
  alertmanagerSpec:
    useExistingSecret: true
    configSecret: alertmanager-private-config
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    ruleSelectorNilUsesHelmValues: false
    ruleNamespaceSelector: {}
```

`useExistingSecret: true` và `configSecret: alertmanager-private-config` được dùng để Alertmanager lấy config từ Secret có sẵn, không hardcode email/app password trong Helm values.

`serviceMonitorSelectorNilUsesHelmValues: false` cho phép Prometheus không bị giới hạn bởi label selector mặc định của chart khi chọn ServiceMonitor.

`serviceMonitorNamespaceSelector: {}` cho phép Prometheus nhìn ServiceMonitor ở nhiều namespace, cụ thể là namespace `demo`.

`ruleSelectorNilUsesHelmValues: false` cho phép Prometheus nhận PrometheusRule không cần label Helm mặc định.

`ruleNamespaceSelector: {}` cho phép Prometheus đọc PrometheusRule ở namespace khác như `demo`.

Những setting này bắt buộc vì ServiceMonitor và PrometheusRule của API nằm ở `demo`, trong khi Prometheus chạy ở `monitoring`.

## 6. App Web Cơ Bản

Path:

`cloud/w9/lab/gitops/k8s`

Resource:

- `Namespace/demo`
- `ConfigMap/web-config`
- `Deployment/web`
- `Service/web`

### 6.1 Namespace

Namespace `demo` có annotation:

```yaml
argocd.argoproj.io/sync-wave: "-1"
```

Namespace được tạo ở wave `-1` vì tất cả resource còn lại cần namespace tồn tại trước.

### 6.2 ConfigMap

ConfigMap `web-config` có:

```yaml
MESSAGE: "hello from gitops"
```

ConfigMap được đặt wave `0` để tạo trước Deployment. Deployment dùng `envFrom.configMapRef`, nên nếu ConfigMap chưa tồn tại pod có thể lỗi.

### 6.3 Deployment

Deployment `web`:

- Image: `nginx:1.27`
- Replicas: `2`
- `revisionHistoryLimit: 2`
- Dùng env từ `web-config`

Chọn Nginx vì đây là image nhỏ, phổ biến, dễ chạy để demo Kubernetes workload mà không cần build app riêng.

`replicas: 2` để chứng minh Kubernetes chạy nhiều pod và Service có thể load-balance.

`revisionHistoryLimit: 2` để giữ lại một số ReplicaSet cũ vừa đủ cho debug/rollback, tránh cluster giữ quá nhiều history.

### 6.4 Service

Service `web`:

- Port: `80`
- TargetPort: `80`
- Selector: `app: web`

Service được đặt wave `2` để tạo sau Deployment. Về kỹ thuật Service có thể tạo trước Deployment, nhưng wave này giúp demo thứ tự rõ ràng: config trước, workload sau, expose cuối.

## 7. App FE/BE

Path:

`cloud/w9/lab/gitops/fe-be`

Resource chính:

- `Namespace/demo-fe-be`
- `Deployment/fe-be-backend`
- `Service/fe-be-backend`
- `Deployment/fe-be-frontend`
- `Service/fe-be-frontend`
- ConfigMap generated từ Kustomize

### 7.1 Vì Sao Dùng Kustomize

Kustomize được dùng để tạo ConfigMap từ file thật:

```yaml
configMapGenerator:
  - name: fe-be-backend-app
    files:
      - app.py=backend/app.py
  - name: fe-be-frontend-config
    files:
      - default.conf=frontend/default.conf
      - index.html=frontend/index.html
```

Lý do chọn cách này:

- Không nhúng code dài trực tiếp vào YAML.
- FE và BE có file riêng, dễ đọc và dễ sửa.
- Manifest vẫn hoàn toàn GitOps được.
- Khi file đổi, Kustomize có thể generate ConfigMap mới để rollout app.

### 7.2 Backend

Backend:

- Image: `python:3.12-alpine`
- Command: `python /app/app.py`
- Port: `8080`
- Replicas: `2`
- Source code mount từ ConfigMap `fe-be-backend-app`

Chọn `python:3.12-alpine` vì không cần build image riêng cho app demo nhỏ. Code được mount vào container từ ConfigMap, giúp thay đổi logic demo nhanh qua Git.

Readiness probe:

```yaml
path: /readyz
initialDelaySeconds: 3
periodSeconds: 5
```

Liveness probe:

```yaml
path: /healthz
initialDelaySeconds: 10
periodSeconds: 10
```

Readiness kiểm tra pod đã sẵn sàng nhận traffic chưa. Liveness kiểm tra app còn sống không để kubelet restart nếu bị treo.

Backend Service:

- Name: `fe-be-backend`
- Port: `8080`
- Selector: `app: fe-be-backend`

Service này chỉ cần internal ClusterIP vì frontend gọi backend qua DNS nội bộ.

### 7.3 Frontend

Frontend:

- Image: `nginx:1.27-alpine`
- Replicas: `2`
- Mount `default.conf` vào `/etc/nginx/conf.d/default.conf`
- Mount `index.html` vào `/usr/share/nginx/html/index.html`

Chọn Nginx Alpine vì nhẹ, phổ biến, đủ để serve static frontend và reverse proxy tới backend.

Frontend Nginx config có:

```nginx
location /api/ {
  resolver 10.96.0.10 valid=10s ipv6=off;
  set $backend "fe-be-backend.demo-fe-be.svc.cluster.local";
  proxy_pass http://$backend:8080/;
}
```

`resolver 10.96.0.10` là DNS service của Kubernetes trong lab. Setting này cần thiết vì `proxy_pass` dùng biến `$backend`; khi Nginx dùng biến trong upstream URL, nó cần resolver runtime.

Frontend Service:

- Type: `NodePort`
- Port: `80`

Chọn NodePort để dễ mở frontend từ môi trường Minikube/local mà không cần Ingress Controller.

### 7.4 Sync Waves FE/BE

FE/BE dùng wave:

- Namespace: `-1`
- ConfigMap generated: `0`
- Backend Service: `0`
- Backend Deployment: `1`
- Frontend Deployment: `2`
- Frontend Service: `3`

Lý do:

- Namespace phải có trước.
- ConfigMap phải có trước Deployment vì pod mount file từ ConfigMap.
- Backend nên sẵn sàng trước frontend vì frontend proxy tới backend.
- Frontend Service tạo sau cùng để expose app khi frontend đã được khai báo.

## 8. API Canary Với Argo Rollouts

Path:

`cloud/w9/lab/gitops/k8s-api`

Resource:

- `Rollout/api`
- `Service/api`
- `AnalysisTemplate/api-success-rate`
- `ServiceMonitor/api`
- `PrometheusRule/api-slo-rules`

### 8.1 Vì Sao Dùng Rollout Thay Deployment

Deployment thường chỉ hỗ trợ rolling update cơ bản. Nó không tự đo metric, không tự pause theo step và không tự abort dựa trên SLO.

Rollout của Argo Rollouts được chọn vì cần:

- Canary theo từng bước.
- Tăng traffic từng phần.
- Chạy analysis giữa các bước.
- Tự abort nếu metric xấu.
- Quan sát rollout bằng CLI/dashboard.

### 8.2 Cấu Hình Rollout

Rollout `api`:

- Namespace: `demo`
- Replicas: `4`
- `revisionHistoryLimit: 4`
- Selector: `app: api`
- Image: `w9-api:1`
- `imagePullPolicy: IfNotPresent`
- Port: `8080`
- Env `ERROR_RATE: "0"`
- Env `VERSION: "v14-final"`

`replicas: 4` được chọn để canary 25% có ý nghĩa rõ: 1 pod canary và 3 pod stable trong giai đoạn đầu.

`ERROR_RATE` là biến điều khiển tỉ lệ lỗi giả lập. Khi set cao như `0.9`, API trả nhiều HTTP 500 để test abort.

`VERSION` dùng để tạo thay đổi trong pod template và giúp nhận biết revision mới.

`imagePullPolicy: IfNotPresent` phù hợp lab local vì image `w9-api:1` có thể được build trong Docker daemon của Minikube. Nếu dùng `Always`, cluster có thể cố pull image từ registry public và fail.

Readiness probe:

```yaml
path: /healthz
port: 8080
```

Probe này đảm bảo pod chỉ nhận traffic khi endpoint health trả OK.

### 8.3 Canary Strategy

Canary steps:

```yaml
steps:
  - setWeight: 25
  - analysis:
      templates:
        - templateName: api-success-rate
  - setWeight: 50
  - analysis:
      templates:
        - templateName: api-success-rate
  - setWeight: 100
```

Luồng này có nghĩa:

1. Đưa version mới nhận 25% traffic.
2. Kiểm tra success rate bằng Prometheus.
3. Nếu pass, tăng lên 50%.
4. Kiểm tra success rate lần nữa.
5. Nếu tiếp tục pass, promote lên 100%.

Lý do không promote thẳng lên 100%:

- Giảm blast radius nếu version mới lỗi.
- Cho phép đo metric thật trên traffic thật.
- Tự động chặn version lỗi trước khi ảnh hưởng toàn bộ người dùng.

## 9. API Demo App

Source app:

`cloud/w9/lab/app/app.py`

Ứng dụng dùng:

- Flask
- `prometheus_flask_exporter`
- Env `ERROR_RATE`
- Env `VERSION`

Endpoint:

- `/`: trả JSON OK hoặc lỗi giả lập.
- `/healthz`: trả `ok`.
- `/metrics`: do `PrometheusMetrics(app)` tự expose.

Logic lỗi giả lập:

```python
if random.random() < ERR:
    return jsonify(error="injected", version=VER), 500
```

Lý do thiết kế như vậy:

- Có thể tạo lỗi có kiểm soát bằng config.
- Không cần thay đổi code để test canary fail.
- Metric HTTP status được exporter ghi nhận để Prometheus tính success rate.

## 10. ServiceMonitor

File:

`cloud/w9/lab/gitops/k8s-api/servicemonitor.yaml`

ServiceMonitor:

- Name: `api`
- Namespace: `demo`
- Selector: `app: api`
- Port: `http`
- Path: `/metrics`
- Interval: `15s`

Lý do dùng ServiceMonitor:

- Đây là cách chuẩn của Prometheus Operator để khai báo target scrape bằng Kubernetes resource.
- Không cần sửa cấu hình Prometheus thủ công.
- Target scrape đi cùng app trong GitOps.

`interval: 15s` được chọn để metric cập nhật đủ nhanh cho canary analysis và alert demo. Nếu interval quá dài, analysis có thể chưa thấy dữ liệu mới kịp thời.

## 11. AnalysisTemplate

File:

`cloud/w9/lab/gitops/k8s-api/analysis-template.yaml`

AnalysisTemplate `api-success-rate` query Prometheus:

```promql
(
  sum(rate(flask_http_request_total{namespace="demo", service="api", status!~"5.."}[1m]))
  /
  sum(rate(flask_http_request_total{namespace="demo", service="api"}[1m]))
) or vector(1)
```

Setting:

- `interval: 20s`
- `count: 3`
- `failureLimit: 1`
- `successCondition: result[0] >= 0.95`
- Prometheus address: `http://kube-prometheus-stack-prometheus.monitoring.svc:9090`

Lý do dùng success rate:

- Canary không chỉ cần pod chạy, mà cần request thành công.
- HTTP 5xx là tín hiệu trực tiếp version mới đang gây lỗi.
- Success rate dễ giải thích khi demo SLO.

Lý do dùng ngưỡng `0.95`:

- Đây là SLO đơn giản: ít nhất 95% request phải thành công.
- Đủ nhạy để bắt version có lỗi cao.
- Dễ test bằng `ERROR_RATE`.

Lý do dùng `[1m]`:

- Phù hợp demo nhanh.
- Không phải chờ lâu như 5m hoặc 30m.
- Vẫn đủ để Prometheus tính rate từ nhiều sample.

Lý do dùng `or vector(1)`:

- Khi chưa có traffic, query có thể rỗng.
- Nếu rỗng, analysis có thể fail không phải vì app lỗi mà vì chưa có dữ liệu.
- `or vector(1)` coi trạng thái không có dữ liệu là healthy trong lab.

`failureLimit: 1` với `count: 3` nghĩa là analysis cho phép một lần đo fail, nhưng nếu fail quá giới hạn thì rollout abort. Đây là cân bằng giữa tránh false positive và vẫn phản ứng nhanh.

## 12. PrometheusRule Và SLO

File:

`cloud/w9/lab/gitops/k8s-api/prometheus-rule.yaml`

PrometheusRule gồm:

- Recording rule: `api:request_success_rate:5m`
- Alert rule: `ApiSLOViolation`

### 12.1 Recording Rule

Recording rule:

```promql
(
  sum(rate(flask_http_request_total{namespace="demo", service="api", status!~"5.."}[5m]))
  /
  sum(rate(flask_http_request_total{namespace="demo", service="api"}[5m]))
) or vector(1)
```

Lý do dùng recording rule:

- Lưu sẵn kết quả query phức tạp thành metric mới.
- Dashboard hoặc query sau này đọc nhanh hơn.
- Tên metric thể hiện ý nghĩa nghiệp vụ rõ hơn raw metric.

### 12.2 Alert Rule

Alert `ApiSLOViolation` fire khi:

```promql
success_rate_1m < 0.95
```

Trong thời gian:

```yaml
for: 30s
```

Lý do dùng `for: 30s`:

- Tránh gửi alert vì spike lỗi rất ngắn.
- Vẫn đủ nhanh để demo email trong lab.
- Phù hợp với scrape interval 15s và analysis interval 20s.

Labels:

```yaml
namespace: demo
severity: page
service: api
slo: "95-percent-success-rate"
```

`namespace: demo` rất quan trọng vì Alertmanager route email match label này.

`severity: page` thể hiện đây là cảnh báo cần chú ý ngay.

`service: api` giúp group và debug đúng service.

`slo` mô tả rule gắn với SLO nào.

Annotations:

- `summary`: mô tả ngắn.
- `description`: có giá trị success rate hiện tại bằng `humanizePercentage`.

## 13. Alertmanager Và Secret Email

### 13.1 Vấn Đề Cần Giải Quyết

Alertmanager cần thông tin SMTP để gửi email:

- Email nhận.
- Email gửi.
- SMTP server.
- Username.
- App password.

Những giá trị này là secret, không được commit lên repo public.

### 13.2 Cách Lab Đang Làm

Repo chỉ commit:

- `cloud/w9/lab/secrets/.env.example`
- `cloud/w9/lab/secrets/apply-alertmanager-secret.ps1`

Repo ignore:

```gitignore
*.pass
secrets/.env
```

File `.env` thật nằm local và không commit.

Script `apply-alertmanager-secret.ps1` đọc `.env`, generate `alertmanager.yaml`, rồi tạo Kubernetes Secret:

- Namespace: `monitoring`
- Secret name: `alertmanager-private-config`
- Key: `alertmanager.yaml`

### 13.3 Vì Sao Dùng Existing Secret

Trong Helm values:

```yaml
alertmanager:
  alertmanagerSpec:
    useExistingSecret: true
    configSecret: alertmanager-private-config
```

Lý do:

- Không lộ secret trong Git.
- Dễ thay đổi email/app password bằng cách sửa `.env` local.
- Không cần sửa Helm Application mỗi lần đổi credential.
- Phù hợp hơn với GitOps so với hardcode secret vào YAML.

Điểm cần hiểu: Secret hiện tại là "local secret workflow", chưa phải sealed secret hoặc external secret. Nó phù hợp lab cá nhân. Nếu production, nên dùng External Secrets Operator, Sealed Secrets, SOPS hoặc secret manager.

### 13.4 Alertmanager Route

Script tạo route:

```yaml
route:
  receiver: 'null'
  group_by:
    - alertname
    - namespace
    - service
  group_wait: 15s
  group_interval: 1m
  repeat_interval: 30m
  routes:
    - receiver: personal-email
      matchers:
        - namespace="demo"
        - alertname=~"Api.*"
```

Default receiver là `null` để alert không liên quan không bị gửi email.

Route `personal-email` chỉ nhận alert:

- Namespace là `demo`.
- Alertname bắt đầu bằng `Api`.

Lý do chọn matcher này:

- Tập trung vào challenge API.
- Tránh spam email bởi alert hệ thống khác từ kube-prometheus-stack.
- Dễ kiểm soát khi demo.

`group_by` theo `alertname`, `namespace`, `service` để các alert cùng service được gom nhóm hợp lý.

`group_wait: 15s` giúp Alertmanager chờ một chút để gom alert trước khi gửi.

`group_interval: 1m` giới hạn tần suất gửi nhóm alert đã có update.

`repeat_interval: 30m` tránh gửi lại liên tục khi alert vẫn firing.

`send_resolved: true` gửi email khi alert resolved để biết sự cố đã hồi phục.

`require_tls: true` yêu cầu SMTP dùng TLS, phù hợp Gmail SMTP.

## 14. GitHub Actions Validation

File:

`.github/workflows/w9-gitops-validate.yml`

Workflow chạy khi:

- Pull request thay đổi file liên quan W9.
- Push vào branch `main` thay đổi file liên quan W9.

Workflow có hai job chính:

- `render-and-validate`
- `kubeconform-lab`

### 14.1 `render-and-validate`

Job này:

- Checkout repo.
- Setup `kubectl`.
- Setup Python 3.12.
- Cài `pyyaml`.
- Render Kustomize cho day-a demo web.
- Render Kustomize cho day-b observability.
- Render Kustomize cho W9 lab FE/BE.
- Parse các YAML quan trọng để bắt lỗi syntax.
- Upload rendered manifest khi push.

Lý do:

- Bắt lỗi YAML sớm trước khi Argo CD sync.
- Kiểm tra output Kustomize thật, không chỉ file source.
- Có artifact rendered manifest để debug.

### 14.2 `kubeconform-lab`

Job này:

- Cài kubeconform `v0.6.7`.
- Render FE/BE bằng Kustomize.
- Validate schema cho `cloud/w9/lab/gitops/k8s/` và output FE/BE rendered.

Lý do dùng kubeconform:

- Kiểm tra resource có đúng Kubernetes schema cơ bản.
- Bắt lỗi field sai, kind sai, apiVersion sai.
- Nhanh và phù hợp CI.

Giới hạn:

- Không kiểm tra CRD đầy đủ nếu schema CRD không được cung cấp.
- Không chứng minh app chạy thật trong cluster.
- Không thay thế được Argo CD sync và runtime testing.

## 15. Namespace Và Ownership

Lab hiện có một điểm cần chú ý: namespace `demo` được dùng bởi cả app `web` và app `api`.

Điều này có thể gây `SharedResourceWarning` nếu cả hai app cùng quản lý resource namespace hoặc resource chung.

Trong GitOps production, nên chọn một trong hai cách:

- Một app platform/base quản lý namespace.
- Các app workload chỉ quản lý resource bên trong namespace, không cùng quản lý namespace.

Trong lab, việc dùng chung `demo` giúp đơn giản hóa demo web và API, nhưng cần hiểu cảnh báo shared resource là dấu hiệu ownership chưa tách hoàn hảo.

## 16. Cách Hệ Thống Tự Hồi Phục

Argo CD tự hồi phục ở cấp GitOps:

- Nếu sửa trực tiếp Deployment/Rollout/Service trong cluster, `selfHeal` đưa về trạng thái trong Git.
- Nếu xóa resource thủ công, Argo CD tạo lại.
- Nếu xóa resource khỏi Git, `prune` xóa khỏi cluster.

Argo Rollouts tự bảo vệ release ở cấp rollout:

- Nếu version mới gây lỗi HTTP 5xx cao, analysis fail.
- Rollout bị abort.
- Stable ReplicaSet tiếp tục phục vụ traffic.

Prometheus/Alertmanager tự cảnh báo ở cấp observability:

- Prometheus phát hiện SLO giảm.
- Alertmanager route alert tới email nếu matcher đúng.

## 17. Cách Test Hệ Thống

### 17.1 Test GitOps Sync

1. Sửa một manifest trong path được Argo CD quản lý.
2. Commit và push lên `main`.
3. Kiểm tra:

```powershell
kubectl -n argocd get applications
```

4. App liên quan sẽ chuyển OutOfSync rồi Synced nếu sync thành công.

### 17.2 Test Web App

Kiểm tra resource:

```powershell
kubectl get ns demo
kubectl -n demo get configmap web-config
kubectl -n demo get deployment web
kubectl -n demo get service web
kubectl -n demo get pods
```

Mục tiêu là thấy namespace, ConfigMap, Deployment, Service và pod đều tồn tại.

### 17.3 Test FE/BE

Kiểm tra:

```powershell
kubectl -n demo-fe-be get pods,svc,configmap
```

Mở frontend bằng Minikube service hoặc port-forward, sau đó gọi `/api/` để xác nhận frontend proxy được tới backend.

### 17.4 Test Canary Thành Công

1. Đảm bảo `ERROR_RATE: "0"`.
2. Đổi `VERSION` sang giá trị mới.
3. Commit và push.
4. Watch rollout:

```powershell
kubectl-argo-rollouts.exe get rollout api -n demo --watch
```

Kết quả mong muốn:

- Canary lên 25%.
- Analysis pass.
- Canary lên 50%.
- Analysis pass.
- Promote 100%.
- Rollout Healthy.

### 17.5 Test Canary Fail

1. Set `ERROR_RATE` cao, ví dụ `"0.9"`.
2. Đổi `VERSION` để tạo revision mới.
3. Commit và push.
4. Watch rollout.

Kết quả mong muốn:

- Canary bắt đầu nhận traffic.
- Prometheus thấy HTTP 500 tăng.
- AnalysisTemplate trả success rate dưới 0.95.
- AnalysisRun failed.
- Rollout aborted.
- Stable version vẫn phục vụ traffic.

Sau test, phải đưa `ERROR_RATE` về `"0"` và đổi `VERSION` để phục hồi.

### 17.6 Test Alert Email

1. Tạo hoặc cập nhật `.env` local từ `.env.example`.
2. Chạy script apply secret.
3. Restart Alertmanager StatefulSet để nhận config mới.
4. Tạo lỗi API bằng canary fail hoặc traffic lỗi.
5. Kiểm tra alert:

```promql
ALERTS{alertname="ApiSLOViolation"}
```

6. Kiểm tra Alertmanager route và metric gửi email.

Nếu Alertmanager metric email request tăng và failed không tăng, Alertmanager đã gửi request thành công. Nếu không thấy trong Inbox, cần kiểm tra Spam/Promotions hoặc cấu hình Gmail/App Password.

## 18. Các Lỗi Thường Gặp Và Lý Do

### 18.1 Argo CD App `Unknown`

Thường do:

- Repo chưa push thay đổi.
- Argo CD chưa refresh xong.
- Repo/path sai.
- Network hoặc credential Git lỗi.
- Resource CRD chưa sẵn sàng.

### 18.2 App `OutOfSync`

Nghĩa là live state khác desired state trong Git. Có thể do:

- Git mới đổi nhưng chưa sync.
- Controller mutate field.
- Resource bị sửa thủ công.
- CRD sinh ra diff không ổn định.

Với `argo-rollouts`, lab đã xử lý CRD diff bằng `ignoreDifferences`.

### 18.3 App `Degraded`

Nghĩa là resource đã apply nhưng health xấu. Ví dụ:

- Pod CrashLoopBackOff.
- Rollout aborted.
- Deployment chưa đủ replica ready.

### 18.4 `another operation is already in progress`

Argo CD đang sync/refresh operation khác. Cách xử lý:

- Chờ operation xong.
- Nếu bị kẹt, terminate operation trong UI/CLI.

### 18.5 `PrometheusRule` Không Apply Được

Lỗi `no matches for kind PrometheusRule` nghĩa là CRD của Prometheus Operator chưa được cài. Cần sync `kube-prometheus-stack` trước.

### 18.6 Không Thấy Email

Các nguyên nhân phổ biến:

- Alert chưa firing.
- Alert thiếu label `namespace: demo`, nên không match route.
- Secret `alertmanager-private-config` chưa apply hoặc Alertmanager chưa restart.
- Gmail App Password sai.
- Email vào Spam/Promotions.
- Alert đã resolved quá nhanh sau khi rollout abort.

## 19. Trade-off Hiện Tại

### 19.1 Điểm Mạnh

- Kiến trúc rõ ràng theo GitOps.
- Có App-of-Apps.
- Có canary rollout dựa trên metric.
- Có SLO rule và alert email.
- Không commit secret thật.
- Có CI validate YAML và manifest render.
- Có app đơn giản và app FE/BE để demo nhiều mức độ.

### 19.2 Điểm Chưa Production-grade

- Secret email dùng `.env` local và script thủ công, chưa dùng External Secrets/SOPS/Sealed Secrets.
- Image `w9-api:1` dùng local image, chưa có container registry versioning chuẩn.
- Namespace `demo` đang có thể bị nhiều app cùng liên quan, có nguy cơ SharedResourceWarning.
- Alert email route còn đơn giản, chưa có escalation policy.
- CI chưa chạy integration test thật trên cluster.
- Chưa có Ingress/TLS chuẩn cho app frontend.

### 19.3 Nếu Nâng Cấp Production

Nên cải tiến:

- Đưa image lên registry và tag immutable theo commit SHA.
- Dùng External Secrets Operator hoặc SOPS để quản lý secret theo GitOps chuẩn.
- Tách namespace ownership ra một app platform/base riêng.
- Thêm Ingress Controller và TLS.
- Thêm dashboard Grafana versioned bằng ConfigMap hoặc Grafana operator.
- Thêm policy validation bằng Conftest/Kyverno/OPA.
- Thêm smoke test sau sync.
- Tách environment `dev/staging/prod` bằng Kustomize overlays.

## 20. Kết Luận

Hệ thống trong `cloud/w9/lab` hiện tại là một lab GitOps đầy đủ theo hướng thực tế: Argo CD quản lý desired state, Argo Rollouts kiểm soát release canary, Prometheus đo metric runtime, Alertmanager gửi cảnh báo, và GitHub Actions kiểm tra manifest trước khi thay đổi đi vào cluster.

Thiết kế này chọn các công nghệ không phải để "cho có", mà để giải quyết từng mục tiêu cụ thể:

- Argo CD giải quyết drift và automation từ Git.
- App-of-Apps giải quyết bootstrap và quản lý nhiều app.
- Sync waves giải quyết thứ tự phụ thuộc resource.
- Argo Rollouts giải quyết release an toàn.
- Prometheus giải quyết đo chất lượng runtime.
- AnalysisTemplate giải quyết quyết định promote/abort tự động.
- PrometheusRule giải quyết SLO và alert.
- Alertmanager Secret giải quyết notification mà không lộ credential.
- GitHub Actions giải quyết validate trước khi sync.

Khi demo, nên trình bày theo luồng: Git thay đổi -> Argo CD sync -> Rollout canary -> Prometheus đo -> Analysis quyết định -> Alertmanager cảnh báo. Đây là trục chính của toàn bộ lab.
