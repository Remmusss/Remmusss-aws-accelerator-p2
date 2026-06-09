# W9 Day C - Progressive Delivery và Canary

## Mục tiêu học

Sau ngày này cần nắm được:

- Progressive delivery khác rolling update thông thường ở điểm nào.
- Argo Rollouts thêm gì so với Kubernetes Deployment mặc định.
- Rollout CRD, AnalysisTemplate, AnalysisRun dùng để làm gì.
- Cách xây canary theo `setWeight`, `pause`, metric analysis.
- Cách auto-abort rollout khi metric xấu.
- Cách kết hợp load test và metric để xác thực rollout.

## Tư duy tổng quan

Mục tiêu Day C không phải "deploy chậm lại". Mục tiêu là:

- đưa version mới ra dần dần
- quan sát metric trong quá trình
- dừng / abort nếu metric xấu
- chỉ promote full traffic khi hệ thống ổn

Canary trong W9 cần dựa trên observability của Day B. Nếu không có metric đáng tin, canary chỉ là rollout chậm, chưa phải progressive delivery đúng nghĩa.

## Phần 1 - Progressive delivery là gì

Argo Rollouts mở rộng khả năng deploy của Kubernetes với:

- blue-green
- canary
- canary analysis
- experimentation
- progressive delivery

Giá trị thêm:

- shift traffic từng phần
- có phân tích metric để quyết định promote hay abort
- tích hợp với ingress controller / service mesh nếu cần

## Phần 2 - Canary strategy cần nhớ

### Các step cơ bản

Trong canary strategy, hai step cần học đầu tiên:

- `setWeight`
- `pause`

Ví dụ tư duy:

1. đưa `10%` traffic vào bản mới
2. đợi `5m`
3. kiểm tra metric
4. lên `25%`
5. kiểm tra tiếp
6. promote full nếu ổn

### Pause

`pause` có thể:

- có `duration`
- hoặc dừng vô thời hạn để đợi người vận hành promote tiếp

Đó là điểm then chốt khi muốn chèn bước observe giữa các lần tăng traffic.

## Phần 3 - Rollout CRD, AnalysisTemplate, AnalysisRun

### Rollout

`Rollout` là thay thế nâng cấp cho `Deployment`.

Nó quản lý:

- strategy `canary` hoặc `blueGreen`
- các step rollout
- traffic progression
- hook sang analysis

### AnalysisTemplate

`AnalysisTemplate` định nghĩa:

- metric nào sẽ được kiểm tra
- query nào dùng để lấy metric
- điều kiện thành công / thất bại
- tần suất kiểm tra
- tham số đầu vào

### AnalysisRun

`AnalysisRun` là instance chạy từ `AnalysisTemplate`.

Kết quả có thể:

- `Successful`
- `Failed`
- `Inconclusive`

Và kết quả đó sẽ ảnh hưởng trực tiếp rollout:

- cho đi tiếp
- abort
- hoặc pause

## Phần 4 - Dùng Prometheus query trong analysis

Argo Rollouts hỗ trợ provider Prometheus trong `AnalysisTemplate`.

Từ tài liệu gốc, có thể khai báo:

- `successCondition`
- `failureCondition`
- `failureLimit`
- `interval`
- `provider.prometheus.address`
- `provider.prometheus.query`

Loại query nên học để viết cho W9:

- success rate
- error rate `5xx`
- request duration percentile
- burn rate query nếu đã có recording rules / metric phù hợp

## Phần 5 - Auto-abort rollout

Nguyên lý:

- rollout tăng traffic từng bước
- sau mỗi bước, chạy analysis
- nếu metric vi phạm `failureCondition` hoặc vượt `failureLimit`, rollout abort

Cho W9, abort criteria nên liên hệ trực tiếp với SLO / SLI của Day B:

- error rate tăng vượt ngưỡng
- latency p95 vượt ngưỡng
- burn rate alert đang firing

Cảnh báo quan trọng:

- ngưỡng quá chặt sẽ abort giả
- ngưỡng quá lỏng sẽ bỏ sót lỗi thật
- canary mà không có load đủ lớn thì metric có thể không đủ tin cậy

## Phần 6 - Kết hợp với burn rate

Announcement nói rõ "integration với burn rate". Cách hiểu đúng:

- Day B tạo SLO và alert logic
- Day C tận dụng cùng metric / logic đó cho canary gate

Hãy nghiêng về 2 kiểu:

- query trực tiếp error rate / latency trên traffic canary
- hoặc query recording rule đã phục vụ burn-rate

Điều quan trọng là cần tách metric của canary khỏi stable bằng labels nếu có thể.

## Phần 7 - Load testing bằng k6

k6 rất hợp để kích traffic có kiểm soát cho canary:

- tạo request rate ổn định
- đặt checks cho response code / body
- đặt thresholds cho latency và error rate

Hai nhóm cần nhớ:

- `checks`: để codify assertion
- `thresholds`: để fail test run, và có thể `abortOnFail`

Ví dụ ý tưởng:

- `http_req_failed: ['rate<0.01']`
- `http_req_duration: ['p(95)<500']`
- `checks: ['rate>0.95']`

Dùng k6 khi:

- cần tạo traffic trước / trong rollout
- cần chứng minh metric xấu thì rollout phải dừng
- cần lặp lại test cùng điều kiện

## Lộ trình học để xong Day C

1. Đọc overview Argo Rollouts để hiểu nó giải bài toán gì.
2. Đọc `Canary` strategy.
3. Đọc `Analysis` và `AnalysisTemplate`.
4. Viết thử 1 `Rollout` có `setWeight` + `pause`.
5. Viết thử 1 `AnalysisTemplate` dùng Prometheus query.
6. Xác định abort criteria dựa trên error rate / latency.
7. Viết 1 script k6 ngắn để tạo traffic và xác thực thresholds.

## Checklist tự kiểm tra

- Giải thích được khác nhau giữa Deployment và Rollout.
- Viết được rollout steps có `setWeight` và `pause`.
- Mô tả được `AnalysisTemplate` và `AnalysisRun`.
- Nói được rollout abort dựa trên metric xấu diễn ra như thế nào.
- Liên hệ được canary gate với SLO / burn rate.
- Biết vì sao cần load test có kiểm soát khi demo canary.

## Bộ tiêu chí tối thiểu cho lab

Rollout cần có:

- canary strategy
- ít nhất 2 mốc `setWeight`
- ít nhất 1 `pause`
- 1 `AnalysisTemplate` dùng Prometheus
- 1 abort criterion rõ ràng
- 1 script k6 để tạo traffic kiểm chứng

## Nguồn tài liệu gốc

- Argo Rollouts overview: https://argoproj.github.io/argo-rollouts/
- Argo Rollouts canary: https://argoproj.github.io/argo-rollouts/features/canary/
- Argo Rollouts analysis: https://argoproj.github.io/argo-rollouts/features/analysis/
- CNCF progressive delivery article: https://www.cncf.io/blog/2024/01/26/progressive-delivery/
- Grafana k6 docs: https://grafana.com/docs/k6/latest/
- k6 thresholds: https://grafana.com/docs/k6/latest/using-k6/thresholds/
- k6 checks: https://grafana.com/docs/k6/latest/javascript-api/k6/check/
