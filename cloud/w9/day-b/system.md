# Day B - System Design: Observability, SLO và Metrics

## 1. Mục tiêu của Day B

Mục tiêu của Day B là biến app W9 thành một hệ thống có thể quan sát được bằng metric, dashboard và alert.

Trước Day B, trạng thái lab là:

- App `demo-web` đã chạy được trong Kubernetes.
- Argo CD đã quản lý app theo GitOps.
- Nhưng app chưa có dữ liệu đủ tốt để ra quyết định vận hành.
- Không có SLO rõ ràng.
- Không có burn-rate alert.
- Không có dashboard gắn với error rate và latency.
- Day C cần metric để auto-abort canary, nhưng metric chưa sẵn sàng.

Mục tiêu hệ thống:

- App phải expose metric thật.
- Prometheus phải scrape được metric đó.
- Grafana có dashboard để nhìn request rate, error rate, latency, burn rate.
- Alert rule phải bám vào SLO/SLI cụ thể.
- Metric phải đủ dùng cho Day C AnalysisTemplate.

Luồng mong muốn:

```text
demo-web
  -> /metrics
  -> ServiceMonitor
  -> Prometheus
  -> PromQL
  -> Grafana dashboard
  -> PrometheusRule alert
  -> Day C AnalysisTemplate
```

## 2. Quyết định quan trọng: tạo app demo có metric thật

Ban đầu app W8/W9 dùng nginx. Nginx trả HTTP tốt, nhưng không tự expose application metrics như:

- tổng request theo status code
- latency histogram
- endpoint `/metrics` chuẩn Prometheus

Vì vậy tôi tạo app demo riêng ở:

```text
cloud/w9/day-b/demo-app/
```

App dùng:

- Flask để viết web server tối giản.
- `prometheus-client` để expose metric.
- Dockerfile để build image local cho minikube.

Lý do chọn Flask:

- Nhỏ, dễ đọc, dễ giải thích.
- Phù hợp lab hơn framework nặng.
- Dễ tạo endpoint `/`, `/slow`, `/error`, `/healthz`, `/metrics`.

Lý do chọn `prometheus-client`:

- Tạo metric Prometheus native.
- Không cần thêm sidecar exporter.
- Prometheus scrape trực tiếp được.
- Dữ liệu metric rõ ràng cho dashboard và analysis.

## 3. Metric được thiết kế như thế nào

App tạo hai metric chính.

### Request counter

```text
demo_web_http_requests_total
```

Labels:

- `app`
- `method`
- `endpoint`
- `status_code`

Vì sao cần labels này:

- `app`: tách `demo-web` và `demo-web-rollout`.
- `method`: biết GET/POST nếu mở rộng.
- `endpoint`: phân biệt `/`, `/slow`, `/error`, `/metrics`, `/healthz`.
- `status_code`: tính error rate bằng `5xx`.

### Latency histogram

```text
demo_web_http_request_duration_seconds
```

Buckets:

```text
0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5
```

Vì sao dùng histogram:

- Prometheus tính được p95 bằng `histogram_quantile`.
- Latency SLO thường quan tâm percentile, không chỉ average.
- Day C cần query p95 để quyết định rollout có an toàn không.

Vì sao bucket có ngưỡng `0.5` và `1`:

- Day B alert latency dùng p95 > 0.5 giây.
- Day C analysis dùng p95 > 1 giây để abort.
- Bucket phải bao phủ các ngưỡng này để query có ý nghĩa.

## 4. Endpoint app được thiết kế để phục vụ demo

App có các endpoint:

- `/`: trả HTTP 200 để tạo traffic tốt.
- `/slow`: sleep 0.75 giây để tạo latency cao.
- `/error`: trả HTTP 500 để tạo error rate.
- `/healthz`: dùng cho readiness/liveness probe.
- `/metrics`: expose Prometheus metrics.

Vì sao cần `/error`:

- Day B cần chứng minh alert error rate.
- Day C cần chứng minh canary auto-abort khi metric xấu.

Vì sao cần `/slow`:

- Cho phép demo latency p95.
- Không cần phá app thật hoặc tạo lỗi khó kiểm soát.

Vì sao `/healthz` tách riêng khỏi `/`:

- Probe nên kiểm tra sức khỏe tối thiểu.
- Endpoint user-facing `/` có thể thay đổi nội dung mà không ảnh hưởng probe.

## 5. Quyết định deploy observability bằng Kustomize

Day B có entrypoint:

```text
cloud/w9/day-b/kustomization.yaml
```

Nó gom:

- Namespace `observability`.
- OTel Collector.
- ServiceMonitor cho `demo-web`.
- PrometheusRule cho SLO.

Vì sao dùng Kustomize:

- Argo CD đọc trực tiếp được.
- `kubectl apply -k` chạy được.
- Phù hợp bundle nhỏ.
- Không cần Helm chart riêng cho nội dung lab.

## 6. Quyết định namespace: tách `observability`

Observability resources nằm trong namespace:

```text
observability
```

Lý do:

- Tách workload app (`lab`) khỏi monitoring stack.
- Dễ nhìn tài nguyên bằng `kubectl get all -n observability`.
- Phù hợp với Helm release `kube-prometheus-stack` đã cài trong namespace này.

App vẫn chạy ở namespace:

```text
lab
```

Điều này buộc `ServiceMonitor` phải dùng `namespaceSelector`.

## 7. Quyết định scrape bằng ServiceMonitor

File:

```text
cloud/w9/day-b/manifests/demo-web-servicemonitor.yaml
```

Setting chính:

```yaml
namespaceSelector:
  matchNames:
    - lab
selector:
  matchLabels:
    app: demo-web
endpoints:
  - port: http
    path: /metrics
    interval: 15s
```

Vì sao dùng `ServiceMonitor`:

- Cluster đã có Prometheus Operator từ `kube-prometheus-stack`.
- `ServiceMonitor` là cách chuẩn để khai báo target scrape bằng Kubernetes CRD.
- Không cần sửa file cấu hình Prometheus thủ công.

Vì sao `ServiceMonitor` nằm ở `observability` nhưng scrape namespace `lab`:

- Prometheus stack quản lý monitoring resources ở `observability`.
- App chạy ở `lab`.
- `namespaceSelector.matchNames` nối hai phần này lại.

Vì sao label `release: kube-prometheus-stack`:

- Kube-prometheus-stack thường chọn `ServiceMonitor` theo label release.
- Nếu thiếu label này, Prometheus có thể không pick up target.

Vì sao scrape interval `15s`:

- Đủ nhanh để dashboard cập nhật rõ trong demo.
- Không quá dày cho lab minikube.
- Day C dùng window 2 phút, nên 15 giây đủ điểm dữ liệu.

## 8. Quyết định dùng PrometheusRule cho SLO

File:

```text
cloud/w9/day-b/alert-rules/demo-web-slo-rules.yaml
```

Alert được tạo:

- `DemoWebHighErrorRate`
- `DemoWebHighLatencyP95`
- `DemoWebBurnRateFast`
- `DemoWebBurnRateSlow`

### Vì sao chọn availability và latency

Đây là hai SLI cơ bản nhất cho HTTP service:

- Availability: request có thành công không.
- Latency: request có đủ nhanh không.

CPU/memory không được chọn làm SLO chính vì đó là internal metric. User không quan tâm CPU bao nhiêu, user quan tâm request có thành công và nhanh không.

### Vì sao error rate threshold là 5%

Lab cần threshold đủ nhạy để demo dễ thấy:

```promql
error_rate > 0.05
```

Nếu đặt quá thấp, alert dễ nhiễu trong môi trường ít traffic. Nếu đặt quá cao, khó chứng minh canary abort.

### Vì sao latency p95 threshold là 0.5 giây

Endpoint `/slow` sleep 0.75 giây, nên p95 > 0.5 giây sẽ bắt được traffic chậm.

### Vì sao có burn-rate fast và slow

Burn rate đo tốc độ tiêu thụ error budget.

Day B dùng:

- Fast window: query `[5m]`, ngưỡng `14.4 * 0.001`.
- Slow window: query `[30m]`, ngưỡng `6 * 0.001`.

Ý nghĩa:

- Fast alert bắt lỗi lớn, xảy ra nhanh.
- Slow alert bắt lỗi nhỏ hơn nhưng kéo dài.

Trong lab, các công thức này giúp nối tư duy Google SRE burn-rate vào PrometheusRule thật.

## 9. Quyết định dùng Grafana dashboard JSON

File:

```text
cloud/w9/day-b/dashboards/demo-web-observability.json
```

Dashboard có các panel:

- Request Rate.
- 5xx Error Rate.
- P95 Latency.
- Burn Rate Proxy.

Vì sao dashboard dùng đúng metric app:

- `demo_web_http_requests_total`
- `demo_web_http_request_duration_seconds_bucket`

Trước đó nếu dùng metric giả định như `http_server_requests_total`, dashboard có thể trống vì app không phát metric đó. Vì vậy dashboard được sửa để khớp metric thật trong app Flask.

## 10. Quyết định vẫn triển khai OTel Collector

File:

```text
cloud/w9/day-b/otel/collector-configmap.yaml
```

Collector bật:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
```

Nghĩa là nhận telemetry qua:

- OTLP gRPC `4317`.
- OTLP HTTP `4318`.

Processors:

- `batch`
- `memory_limiter`
- `resource`

Vì sao dùng `batch`:

- Gom telemetry trước khi export.
- Giảm overhead.

Vì sao dùng `memory_limiter`:

- Tránh collector dùng quá nhiều RAM trong lab.
- Setting:
  - `limit_mib: 256`
  - `spike_limit_mib: 64`
  - `check_interval: 1s`

Vì sao dùng `resource` processor:

- Gắn attribute:
  - `k8s.cluster.name=w9-lab`
- Giúp telemetry có ngữ cảnh cluster nếu mở rộng về sau.

Exporters:

- `debug`
- `prometheus` tại `0.0.0.0:8889`

Vì sao vẫn có OTel Collector dù app hiện expose Prometheus trực tiếp:

- Day B cần học OTel pipeline.
- Collector là điểm mở rộng cho app instrument bằng OTLP về sau.
- App hiện tại dùng Prometheus direct để demo có data chắc chắn.
- Hai hướng này không mâu thuẫn: direct Prometheus phục vụ demo, OTel Collector phục vụ kiến trúc mở rộng.

## 11. Từ trạng thái chưa có gì đến Day B chạy được

Điểm khởi đầu:

- Day A đã có app `demo-web` trong namespace `lab`.
- Argo CD đã sync được app.
- Cluster đã cài kube-prometheus-stack.
- Nhưng app chưa có metric thật.

Các bước hệ thống:

1. Tạo app Flask có endpoint `/metrics`.
2. Build image `demo-web-metrics:local` vào minikube.
3. Day A deployment dùng image này thay vì nginx.
4. Day B tạo namespace `observability`.
5. Day B triển khai OTel Collector.
6. Day B tạo `ServiceMonitor` để Prometheus scrape `demo-web` ở namespace `lab`.
7. Day B tạo `PrometheusRule` cho SLO.
8. Dashboard Grafana dùng metric thật để hiển thị.
9. Endpoint `/error` và `/slow` tạo tín hiệu lỗi/chậm để demo.

Kết quả Day B:

- App có metrics thật.
- Prometheus scrape được app.
- Grafana có dashboard.
- PrometheusRule có alert availability, latency, burn rate.
- Day C có nền metric để dùng cho canary analysis.
