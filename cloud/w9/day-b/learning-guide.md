# W9 Day B - Observability, SLO, SLI, OTel

## Mục tiêu học

Sau ngày này cần nắm được:

- Observability stack trong W9 gồm những thành phần nào và mỗi thành phần làm gì.
- SLI, SLO, SLA khác nhau ra sao.
- Vì sao availability và latency là hai SLO khởi đầu hợp lý.
- OpenTelemetry SDK và Collector nằm ở đâu trong pipeline telemetry.
- Prometheus, Grafana, Loki kết hợp thế nào.
- Burn rate alert là gì và vì sao dùng multi-window.

## Biểu đồ tư duy tổng quan

Pipeline tối thiểu cho W9:

`app -> OTel instrumentation -> OTel Collector -> Prometheus / Loki / backend -> Grafana dashboards + alerting`

Trong đó:

- OTel giúp app phát sinh telemetry có cấu trúc.
- Collector nhận, xử lý, enrich và gửi telemetry.
- Prometheus giữ metrics và cho query theo time series.
- Loki giữ logs.
- Grafana dùng để query, dashboard, alert.

## Phần 1 - Hiểu đúng observability

Observability không chỉ là "có metrics". Mục tiêu là:

- nhìn thấy hệ thống đang ra sao
- truy vết nhanh khi có incident
- liên hệ metric kỹ thuật với trải nghiệm người dùng
- ra quyết định deploy / rollback bằng dữ liệu

W9 đẩy mạnh observability vì Day C cần metric để auto-abort canary.

## Phần 2 - SLI, SLO, SLA

### Định nghĩa cần nhớ

- `SLI`: metric định lượng một khía cạnh chất lượng dịch vụ.
- `SLO`: mục tiêu đặt ra cho SLI trong một khoảng thời gian.
- `SLA`: cam kết đối ngoại, thường gắn với pháp lý / kinh doanh.

Google SRE nhấn mạnh SLI/SLO/SLA là cách biến metric thành hành động vận hành.

### Hai SLI khởi đầu nên học trước

- `Availability`: tỉ lệ request thành công.
- `Latency`: tỉ lệ request nhanh hơn một ngưỡng.

Ví dụ cho HTTP API:

- Availability SLI: tỷ lệ request không trả `5xx`
- Latency SLI: tỷ lệ request có `p95 < 300ms` hoặc "95% request < 300ms"

### Error budget

Nếu SLO không phải 100%, phần chưa đạt đó là error budget.

Ý nghĩa thực tế:

- còn budget: có thể tiếp tục release nhanh hơn
- hết budget: phải ưu tiên reliability, giảm thay đổi, thậm chí freeze deploy

## Phần 3 - OpenTelemetry cần học những gì

### 1. Các signal

OpenTelemetry hỗ trợ các signal chính:

- `Traces`
- `Metrics`
- `Logs`
- `Baggage`

Cho W9, cần ưu tiên metrics và logs; traces nên biết để mở rộng sau.

### 2. SDK vs Collector

#### SDK / Instrumentation

Đặt trong app hoặc auto-instrumentation:

- tạo spans
- ghi metrics
- gắn context giữa request / trace / log

#### Collector

Collector là lớp trung gian vendor-agnostic, có các component:

- `Receivers`: nhận telemetry
- `Processors`: lọc, biến đổi, enrich
- `Exporters`: gửi đến backend
- `Connectors`: nối hai pipeline
- `Extensions`: health check và khả năng phụ

Nhớ mẫu:

- app không nên export từng nơi một cách mạnh ai nấy làm
- Collector giúp chuẩn hóa, đổi backend dễ hơn, giảm coupling

## Phần 4 - Prometheus, Grafana, Loki

### Prometheus

Cần nhớ 5 điểm:

- metrics được lưu dưới dạng time series
- mỗi metric có labels
- thu thập theo `pull model` qua HTTP
- query bằng `PromQL`
- có thể kết hợp Alertmanager cho alert

Prometheus rất hợp để tính SLI availability, latency, error rate, saturation.

### Grafana

Grafana là lớp visualization và alert:

- tạo dashboards
- truy vấn nhiều datasource
- tạo alert rule trên metrics và logs
- quản lý notification và triage alert tập trung

Cho W9, dashboard tối thiểu nên có:

- request rate
- error rate
- p50 / p95 / p99 latency
- CPU / memory / restart
- SLO status và error budget burn

### Loki

Stack Loki có 3 thành phần cơ bản:

- agent scrape log và gắn labels
- Loki ingest + store + query logs
- Grafana để hiển thị và truy vấn

Loki hợp để:

- xem log theo label `namespace`, `app`, `pod`
- liên kết metric spike với log lỗi
- debug rollout failure

## Phần 5 - SLO methodology cho bài W9

### Bắt đầu đơn giản

Theo Google SRE Workbook, khi bắt đầu hãy chọn SLI đơn giản, thường là availability và latency.

Mẫu thực hành:

- Availability objective: `99.9%` request non-5xx trong 30 ngày
- Latency objective: `95%` request dưới `300ms` trong 30 ngày

### Cách nghĩ đúng

Đừng viết SLO theo kiểu "CPU < 70%" làm mục tiêu chính cho user-facing service. CPU là metric nội bộ, không phải service outcome.

Hãy ưu tiên:

- user request thành công không
- request có nhanh đủ không
- nếu có async job thì cần freshness / completion rate

## Phần 6 - Burn rate alert

### Burn rate là gì

Burn rate đo tốc độ tiêu thụ error budget.

Ví dụ:

- SLO 99.9% trong 30 ngày cho phép 0.1% lỗi
- nếu hiện tại lỗi quá nhanh, budget sẽ "cháy" nhanh hơn mức cho phép

### Vì sao multi-window, multi-burn-rate

Google SRE Workbook đề xuất alert nhiều cửa sổ để:

- phát hiện nhanh sự cố lớn
- giảm false positive
- tránh case spike ngắn hạn và case suy giảm dài hơn bị bỏ sót

Trong announcement, pattern cần học là:

- fast: `1h x 5m`
- slow: `6h x 30m`

Ý nghĩa:

- cửa sổ ngắn để bắt issue đang cháy rất nhanh
- cửa sổ dài để bắt issue âm ỉ nhưng vẫn ăn budget

## Lộ trình học để xong Day B

1. Đọc phần SLI/SLO của Google SRE Book.
2. Đọc `Implementing SLOs` để hiểu availability, latency, error budget.
3. Đọc `Alerting on SLOs` để hiểu burn rate và multi-window alert.
4. Đọc OTel concepts về signals.
5. Đọc OTel Collector components.
6. Đọc overview của Prometheus, Grafana dashboards/alerting, Loki overview.
7. Tự vẽ 1 dashboard + 1 alert rule + 2 SLO ban đầu cho service W8.

## Checklist tự kiểm tra

- Phân biệt được SLI, SLO, SLA mà không nhầm.
- Viết được 2 SLI cho HTTP service: availability và latency.
- Giải thích được error budget dùng để làm gì.
- Mô tả được pipeline `OTel SDK -> Collector -> backend`.
- Giải thích vì sao Prometheus hợp cho metrics và Loki hợp cho logs.
- Nói được vì sao burn rate alert dùng 2 cửa sổ thời gian.

## Dashboard và alert tối thiểu cho lab

Nên có ít nhất:

- 1 dashboard service health
- 1 dashboard infrastructure
- 1 alert error-rate hoặc burn-rate
- 1 alert latency
- 1 view logs theo `app`, `namespace`, `pod`

## Nguồn tài liệu gốc

- OpenTelemetry concepts: https://opentelemetry.io/docs/concepts/
- OpenTelemetry signals: https://opentelemetry.io/docs/concepts/signals/
- OpenTelemetry Collector components: https://opentelemetry.io/docs/collector/components/
- Prometheus overview: https://prometheus.io/docs/introduction/overview/
- Grafana dashboards: https://grafana.com/docs/grafana/latest/visualizations/dashboards/
- Grafana alerting: https://grafana.com/docs/grafana/latest/alerting/
- Loki overview: https://grafana.com/docs/loki/latest/get-started/overview/
- Google SRE SLO chapter: https://sre.google/sre-book/service-level-objectives/
- Google SRE Workbook implementing SLOs: https://sre.google/workbook/implementing-slos
- Google SRE Workbook alerting on SLOs: https://sre.google/workbook/alerting-on-slos
