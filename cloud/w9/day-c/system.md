# Day C - System Design: Progressive Delivery và Canary Auto-Abort

## 1. Mục tiêu của Day C

Mục tiêu của Day C là triển khai progressive delivery bằng canary và tự động abort khi metric xấu.

Trước Day C, hệ thống đã có:

- Day A: GitOps với Argo CD.
- Day B: App có metric Prometheus thật.
- Prometheus scrape được metric.
- Alert rule và dashboard đã có.

Nhưng vẫn còn thiếu:

- Deploy version mới theo từng bước.
- Chặn rollout khi error rate hoặc latency xấu.
- Cơ chế dùng metric để quyết định promote hay abort.
- Bằng chứng thực hành rằng lỗi metric làm rollout dừng.

Mục tiêu hệ thống:

- Dùng `Rollout` thay cho `Deployment` trong phần canary.
- Tăng traffic theo từng mốc.
- Chạy Prometheus analysis giữa các mốc.
- Nếu metric đạt, rollout promote.
- Nếu metric xấu, rollout abort.
- Có script tạo traffic tốt/xấu để kiểm chứng.

Luồng mong muốn:

```text
Patch image v1 -> v2
  -> Argo Rollouts tạo ReplicaSet mới
  -> setWeight 20%
  -> pause
  -> AnalysisTemplate query Prometheus
  -> setWeight 50%
  -> pause
  -> AnalysisTemplate query Prometheus
  -> promote 100% nếu tốt
  -> abort nếu error rate hoặc latency vượt ngưỡng
```

## 2. Quyết định chính: dùng Argo Rollouts

Kubernetes `Deployment` mặc định có rolling update, nhưng không đủ cho mục tiêu Day C.

Deployment có thể:

- Tạo ReplicaSet mới.
- Rolling update dần pod.
- Rollback cơ bản.

Deployment không có sẵn:

- Canary step rõ ràng như 20%, 50%, 100%.
- Pause giữa các bước.
- Analysis bằng Prometheus.
- Auto-abort theo metric.

Vì vậy tôi dùng Argo Rollouts.

Lý do chọn Argo Rollouts:

- Có CRD `Rollout`.
- Có `AnalysisTemplate` và `AnalysisRun`.
- Tích hợp Prometheus provider.
- Phù hợp với Argo CD ở Day A.
- Dễ demo trạng thái promote/abort bằng `kubectl describe`.

## 3. Vì sao tạo app canary riêng `demo-web-rollout`

Day C không sửa trực tiếp app `demo-web` của Day A. Thay vào đó tạo app riêng:

```text
demo-web-rollout
```

Lý do:

- Không phá app nền đang được Argo CD quản lý ổn định.
- Có thể thực hành abort mà không ảnh hưởng dashboard Day B của `demo-web`.
- Metric tách bằng label `app="demo-web-rollout"`.
- Dễ phân biệt stable app và canary app khi query Prometheus.

Namespace vẫn là:

```text
lab
```

Vì đây vẫn là workload application.

## 4. Quyết định Rollout spec

File:

```text
cloud/w9/day-c/rollout/demo-web-rollout.yaml
```

Các setting chính:

```yaml
replicas: 5
revisionHistoryLimit: 3
```

Vì sao dùng `replicas: 5`:

- Canary 20% tương ứng 1 pod.
- Canary 50% tương ứng khoảng 3 pod.
- Nếu chỉ có 1 hoặc 2 replica, phần trăm canary khó quan sát.

Vì sao `revisionHistoryLimit: 3`:

- Giữ đủ ReplicaSet gần nhất để quan sát và rollback trong lab.
- Không để lịch sử ReplicaSet tăng mãi.

Container dùng:

```yaml
image: demo-web-metrics:v1
imagePullPolicy: IfNotPresent
```

Vì sao dùng `demo-web-metrics:v1`:

- Đây là image app có `/metrics`, `/error`, `/slow`.
- Metric format đã tương thích Day B.

Vì sao `IfNotPresent`:

- Image được build local vào minikube.
- Không pull từ registry public.

Env:

```yaml
APP_NAME=demo-web-rollout
APP_VERSION=v1
```

Vì sao cần `APP_NAME`:

- Metric có label `app`.
- Day C query Prometheus theo `app="demo-web-rollout"`.
- Tách metric khỏi Day B app `demo-web`.

Vì sao cần `APP_VERSION`:

- Dễ quan sát version đang chạy khi gọi `/`.
- Patch sang `v2` có thể đổi cả image và version.

## 5. Quyết định canary steps

Canary strategy:

```yaml
steps:
  - setWeight: 20
  - pause:
      duration: 30s
  - analysis:
      templates:
        - templateName: demo-web-prometheus-analysis
  - setWeight: 50
  - pause:
      duration: 30s
  - analysis:
      templates:
        - templateName: demo-web-prometheus-analysis
  - setWeight: 100
```

Vì sao chọn 20%:

- Với 5 replicas, 20% là 1 pod canary.
- Đây là mức đủ nhỏ để giảm rủi ro.
- Dễ quan sát ReplicaSet mới có 1 pod.

Vì sao chọn 50%:

- Đây là bước giữa đủ lớn để metric có thêm dữ liệu.
- Nếu lỗi chỉ xuất hiện khi traffic tăng, bước 50% có cơ hội phát hiện.

Vì sao có `pause 30s`:

- Cho pod mới có thời gian nhận traffic và sinh metric.
- Cho Prometheus có thời gian scrape.
- Tránh analysis chạy ngay khi chưa có dữ liệu.

Vì sao có analysis sau từng pause:

- Rollout không chỉ tăng traffic theo thời gian.
- Rollout phải kiểm tra dữ liệu thật trước khi đi tiếp.

Vì sao không dùng traffic manager/service mesh:

- Lab hiện chưa có Istio, NGINX Ingress traffic splitting, hoặc ALB weighted routing.
- Với Kubernetes service thường, Argo Rollouts có thể scale ReplicaSet để xấp xỉ canary weight.
- Cách này đủ cho mục tiêu học Rollout + AnalysisTemplate.

## 6. Quyết định Service riêng

File:

```text
cloud/w9/day-c/rollout/demo-web-service.yaml
```

Service:

```yaml
name: demo-web-rollout
type: NodePort
nodePort: 32124
```

Vì sao service riêng:

- Không đụng service `demo-web` của Day A.
- Dễ port-forward riêng qua `8082`.
- Prometheus ServiceMonitor chọn đúng label `app=demo-web-rollout`.

Vì sao `NodePort 32124`:

- Day A app dùng `32123`.
- Day C dùng `32124` để tránh conflict.

## 7. Quyết định ServiceMonitor riêng

File:

```text
cloud/w9/day-c/rollout/demo-web-servicemonitor.yaml
```

Setting:

```yaml
namespace: observability
labels:
  release: kube-prometheus-stack
namespaceSelector:
  matchNames:
    - lab
selector:
  matchLabels:
    app: demo-web-rollout
endpoints:
  - port: http
    path: /metrics
    interval: 10s
```

Vì sao dùng ServiceMonitor riêng:

- Day C app có label và metric label riêng.
- Không trộn target scrape với `demo-web`.
- Dễ xác nhận Prometheus đang scrape canary target.

Vì sao interval `10s`:

- AnalysisTemplate dùng interval `20s`.
- Prometheus scrape 10s giúp mỗi analysis measurement có dữ liệu mới hơn.
- Demo canary cần phản hồi nhanh.

Vì sao vẫn dùng label `release: kube-prometheus-stack`:

- Prometheus Operator trong lab chọn ServiceMonitor theo label này.
- Nếu thiếu, target có thể không được scrape.

## 8. Quyết định AnalysisTemplate

File:

```text
cloud/w9/day-c/analysis-template/demo-web-prometheus-analysis.yaml
```

AnalysisTemplate có hai metric:

- `error-rate`
- `p95-latency`

Provider:

```yaml
prometheus:
  address: http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090
```

Vì sao dùng service DNS nội bộ:

- Rollouts controller chạy trong cluster.
- Prometheus service cũng trong cluster.
- DNS Kubernetes ổn định hơn port-forward local.

## 9. Vì sao chọn error-rate làm abort criterion

Query:

```promql
(
  sum(rate(demo_web_http_requests_total{app="demo-web-rollout", status_code=~"5.."}[2m]))
  /
  clamp_min(sum(rate(demo_web_http_requests_total{app="demo-web-rollout"}[2m])), 0.001)
) or vector(0)
```

Điều kiện:

```yaml
successCondition: result[0] <= 0.05
failureCondition: result[0] > 0.05
failureLimit: 1
interval: 20s
count: 3
```

Vì sao threshold 5%:

- Phù hợp với Day B `DemoWebHighErrorRate`.
- Dễ chứng minh bằng endpoint `/error`.
- Không quá nhạy với vài request lỗi đơn lẻ nếu traffic đủ.

Vì sao window `[2m]`:

- Ngắn đủ để demo nhanh.
- Dài đủ để Prometheus có vài điểm scrape.

Vì sao dùng `clamp_min(..., 0.001)`:

- Tránh chia cho 0 khi chưa có traffic.
- Giúp query luôn trả số thay vì lỗi/NaN.

Vì sao thêm `or vector(0)`:

- Nếu Prometheus chưa có series, query vẫn trả `0`.
- Điều này giúp initial rollout không fail chỉ vì chưa có traffic.

Vì sao `failureLimit: 1`:

- Chỉ cần vượt ngưỡng hơn 1 lần là đủ để abort trong lab.
- Làm demo auto-abort rõ ràng.

Vì sao `count: 3` và `interval: 20s`:

- Mỗi analysis đo tối đa 3 lần.
- Nếu pass cả 3 lần, metric được coi là ổn.
- Tổng thời gian đủ ngắn để demo nhưng vẫn có nhiều measurement.

## 10. Vì sao chọn p95-latency làm abort criterion

Query:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(demo_web_http_request_duration_seconds_bucket{app="demo-web-rollout"}[2m])
  )
) or vector(0)
```

Điều kiện:

```yaml
successCondition: result[0] <= 1
failureCondition: result[0] > 1
```

Vì sao p95:

- p95 phản ánh trải nghiệm của phần lớn request nhưng vẫn nhạy với tail latency.
- Average latency có thể che giấu request chậm.

Vì sao threshold 1 giây:

- Endpoint `/slow` sleep 0.75 giây.
- Threshold 1 giây tránh abort giả trong lab.
- Nếu muốn demo latency abort rõ hơn, có thể hạ threshold hoặc tăng traffic vào `/slow`.

## 11. Quyết định dùng patch file để đổi version

Files:

```text
cloud/w9/day-c/patches/image-v1-merge.json
cloud/w9/day-c/patches/image-v2-merge.json
```

Vì sao dùng patch file:

- Máy chưa có plugin `kubectl argo rollouts`.
- `kubectl set image` không hỗ trợ tốt CRD Rollout trong client hiện tại.
- JSON inline trong PowerShell dễ lỗi quote.
- `--patch-file` ổn định và ghi lại được cách thực hành trong repo.

Patch `v2` đổi:

- `image: demo-web-metrics:v2`
- `APP_VERSION=v2`

Patch `v1` đổi:

- `image: demo-web-metrics:v1`
- `APP_VERSION=v1`

Khi Pod template đổi, Argo Rollouts tạo ReplicaSet mới và bắt đầu canary.

## 12. Quyết định load test

Files:

```text
cloud/w9/day-c/load-tests/k6-canary-good.js
cloud/w9/day-c/load-tests/k6-canary-bad.js
```

`k6-canary-good.js`:

- Gửi request vào `/`.
- Threshold:
  - `http_req_failed < 1%`
  - `p95 < 1000ms`

Mục tiêu:

- Tạo traffic tốt để rollout promote.

`k6-canary-bad.js`:

- Khoảng 35% request vào `/error`.
- Làm error rate vượt 5%.

Mục tiêu:

- Chứng minh AnalysisTemplate fail.
- Chứng minh Rollout auto-abort.

Vì sao vẫn có fallback PowerShell trong runbook:

- Máy có thể chưa cài k6.
- PowerShell `Invoke-WebRequest` đủ để tạo traffic lỗi trong lab.

## 13. Kết quả đã kiểm chứng

Tôi đã chạy thực tế trên cluster:

- Cài Argo Rollouts CRD/controller.
- Build image `demo-web-metrics:v1`.
- Build image `demo-web-metrics:v2`.
- Apply Day C.
- Rollout ban đầu Healthy.
- Patch sang `v2`.
- Rollout lên 20%, chạy analysis.
- AnalysisRun thứ nhất `Successful`.
- Rollout lên 50%, chạy analysis.
- AnalysisRun thứ hai `Successful`.
- Rollout promote 100%.
- Patch lại `v1` để tạo revision mới.
- Tạo traffic lỗi vào `/error`.
- AnalysisRun fail vì `error-rate` vượt 5%.
- Rollout abort và chuyển trạng thái `Degraded`.
- Sau đó đưa Rollout về trạng thái Healthy bằng patch stable.

Evidence quan trọng từ cluster:

- `AnalysisRun` successful có measurement `error-rate` <= 0.05.
- `AnalysisRun` failed có measurement `error-rate` khoảng 0.25 đến 0.36.
- Rollout có message:
  - `RolloutAborted`
  - `Metric "error-rate" assessed Failed`

## 14. Từ trạng thái chưa có gì đến Day C chạy được

Điểm khởi đầu:

- Day A đã có GitOps app.
- Day B đã có Prometheus metrics.
- Cluster chưa có Argo Rollouts CRD.
- Chưa có Rollout resource.
- Chưa có AnalysisTemplate.

Các bước hệ thống:

1. Cài Argo Rollouts vào namespace `argo-rollouts`.
2. Build image `demo-web-metrics:v1` và `demo-web-metrics:v2` vào minikube.
3. Apply `cloud/w9/day-c`.
4. Rollout tạo ReplicaSet stable đầu tiên.
5. Service expose `demo-web-rollout`.
6. ServiceMonitor cho Prometheus scrape `/metrics`.
7. Patch image sang `v2`.
8. Rollout tạo ReplicaSet canary.
9. Rollout chạy step 20%.
10. Rollout pause 30 giây.
11. AnalysisTemplate query Prometheus.
12. Nếu pass, rollout lên 50%.
13. Nếu pass tiếp, rollout lên 100%.
14. Nếu error rate hoặc latency fail, rollout abort.

Kết quả Day C:

- Progressive delivery đã chạy thật.
- Canary không chỉ dựa vào thời gian, mà dựa vào metric.
- Prometheus metric từ Day B được dùng làm gate.
- Auto-abort đã được chứng minh bằng lỗi chủ động.
