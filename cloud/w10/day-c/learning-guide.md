# W10 Day C - Learning Guide: Platform Integration + Runbook + Cost Guard

## 1. Ngày này cần học gì

Day C cần học cách nối các phần đã học thành một mini platform vận hành được:

- GitOps từ W9.
- Observability từ W9.
- Canary rollout từ W9.
- RBAC và admission policy từ Day A.
- Secret rotation và supply chain security từ Day B.
- Resource/cost guard.
- Runbook và incident response.

Mục tiêu là chuyển từ học từng công cụ riêng lẻ sang hiểu cách cả platform hoạt động end-to-end.

## 2. Platform integration cần học gì và vì sao

### 2.1. Bootstrap từ fresh cluster

Cần học:

- Cluster cần cài controller nào trước.
- CRD phải có trước custom resource.
- App workload nên deploy sau policy, secret, monitoring và rollout controller.
- Cách ghi lại bootstrap order để người khác làm lại được.

Vì sao phải học:

- Mục tiêu W10 là mini platform deploy lên fresh cluster trong dưới 2 giờ.
- Nếu thứ tự sai, Argo CD có thể apply resource trước khi CRD tồn tại.
- Fresh cluster test là cách tốt nhất để biết repo có tái dựng được platform hay không.

Liên quan tới yêu cầu tuần:

- W10 yêu cầu "Mini platform working end-to-end".
- Day C là ngày ghép toàn stack W8 -> W10.

### 2.2. App-of-Apps trong Argo CD

Cần học:

- Root Application quản lý nhiều Application con.
- Mỗi app con có path, namespace và sync policy riêng.
- App-of-Apps giúp bootstrap platform bằng một entrypoint.

Vì sao phải học:

- Platform có nhiều phần: monitoring, rollouts, policies, secrets, app.
- Apply thủ công từng file rất dễ lệch trạng thái.
- App-of-Apps giúp Git là source of truth cho toàn platform.

Liên quan tới yêu cầu tuần:

- W9 đã học GitOps.
- W10 yêu cầu tích hợp GitOps với observability, canary và security.

### 2.3. Sync order và dependency

Cần học:

- Namespace cần có trước resource trong namespace.
- Controller/CRD cần có trước CR custom resource.
- Secret sync cần có trước app dùng secret.
- Monitoring cần có trước canary analysis nếu rollout phụ thuộc Prometheus.

Vì sao phải học:

- Platform integration thường fail không phải vì YAML sai, mà vì thứ tự dependency sai.
- Hiểu dependency giúp debug Argo CD OutOfSync/Degraded nhanh hơn.

Liên quan tới yêu cầu tuần:

- Day C yêu cầu tích hợp toàn stack.
- Lab show-and-tell cần demo flow mượt, không phụ thuộc thao tác thủ công.

### 2.4. `prune`, `selfHeal`, `CreateNamespace`, `ServerSideApply`

Cần học:

- `prune` xóa resource không còn trong Git.
- `selfHeal` sửa drift khi live state bị sửa ngoài Git.
- `CreateNamespace` giúp Argo CD tạo namespace đích.
- `ServerSideApply` hữu ích với CRD/resource lớn hoặc resource bị controller mutate.

Vì sao phải học:

- Đây là các setting quyết định GitOps có thật sự quản lý state hay không.
- Không có `selfHeal`, sửa tay trong cluster có thể tồn tại lâu.
- Không có `prune`, resource cũ có thể thành rác hoặc rủi ro bảo mật.

Liên quan tới yêu cầu tuần:

- W10 muốn hardening không dựa vào lời hứa.
- GitOps setting giúp giảm drift và giữ platform đúng desired state.

## 3. ResourceQuota và LimitRange cần học gì và vì sao

### 3.1. Resource requests và limits

Cần học:

- `requests.cpu` và `requests.memory` là tài nguyên workload yêu cầu scheduler đảm bảo.
- `limits.cpu` và `limits.memory` là trần sử dụng runtime.
- CPU vượt limit thường bị throttle.
- Memory vượt limit có thể bị OOMKilled.

Vì sao phải học:

- Không hiểu request/limit thì không thể đặt quota đúng.
- Workload thiếu request/limit làm capacity planning và cost control kém.
- Policy Day A bắt buộc requests/limits cần được hiểu ở Day C.

Liên quan tới yêu cầu tuần:

- D3 yêu cầu ResourceQuota + LimitRange.
- Lab cleanup có risk workload không có resource guard.

### 3.2. ResourceQuota

Cần học:

- `ResourceQuota` giới hạn tổng tài nguyên trong namespace.
- Có thể giới hạn CPU, memory, số pod, service, secret, configmap.
- Quota hoạt động ở namespace level.

Vì sao phải học:

- Ngăn một namespace chiếm hết tài nguyên cluster.
- Giúp môi trường lab không scale nhầm gây tốn chi phí.
- Tạo boundary rõ giữa team/app namespace.

Liên quan tới yêu cầu tuần:

- W10 có Cost Guard.
- ResourceQuota là cost guard trực tiếp trong Kubernetes.

### 3.3. LimitRange

Cần học:

- `LimitRange` đặt default request/limit.
- Có thể đặt min/max cho container.
- Giúp namespace có baseline dù developer quên khai báo.

Vì sao phải học:

- Nếu chỉ có quota mà pod không khai request, hành vi có thể không như mong muốn.
- Default request/limit giúp workload demo không bị reject quá nhiều nhưng vẫn có guard.
- Min/max giúp chặn container quá nhỏ hoặc quá lớn.

Liên quan tới yêu cầu tuần:

- D3 yêu cầu ResourceQuota + LimitRange đi cùng nhau.
- Đây là phần nối Day A policy với vận hành thực tế.

## 4. Cost guard AWS cần học gì và vì sao

### 4.1. AWS Cost Anomaly Detection

Cần học:

- Cost Anomaly Detection theo dõi chi phí bất thường.
- Có monitor, threshold và subscriber.
- Có thể theo dõi theo AWS service hoặc account.

Vì sao phải học:

- Kubernetes/EKS có thể tạo chi phí qua Load Balancer, NAT Gateway, EBS, CloudWatch logs.
- Cost issue cũng là incident vận hành.
- Lab cần cơ chế cảnh báo khi chi phí vượt bất thường.

Liên quan tới yêu cầu tuần:

- D3 yêu cầu AWS Cost Anomaly Detection.
- W10 theme "Secure & Operate" bao gồm vận hành chi phí, không chỉ security.

### 4.2. Tagging standard

Cần học:

- Tag như `Project`, `Owner`, `Environment`, `TTL`, `CostCenter`.
- Tag giúp cost allocation và cleanup.
- Tag phải nhất quán từ AWS resource đến Kubernetes label nếu có thể.

Vì sao phải học:

- Khi có chi phí bất thường, cần biết tài nguyên thuộc ai.
- `TTL` giúp dọn tài nguyên lab sau khi học.
- Tag/label là nền cho ownership và runbook.

Liên quan tới yêu cầu tuần:

- Day A đã yêu cầu label ownership.
- Day C mở rộng ownership đó sang cost guard.

## 5. Chaos test cần học gì và vì sao

### 5.1. Chaos test đơn giản bằng `kubectl`

Cần học:

- Xóa pod để kiểm tra ReplicaSet/Rollout tự phục hồi.
- Quan sát pod mới, endpoint, metric và alert.
- Ghi lại thời gian phục hồi.

Vì sao phải học:

- Platform chỉ đáng tin khi đã kiểm thử khả năng phục hồi.
- Xóa pod là chaos test đơn giản nhưng đủ chứng minh controller hoạt động.
- Không cần tool phức tạp trước khi hiểu failure mode cơ bản.

Liên quan tới yêu cầu tuần:

- D3 yêu cầu chaos test.
- Lab cần evidence vận hành, không chỉ deploy thành công.

### 5.2. Canary failure test

Cần học:

- Cách tạo version lỗi có kiểm soát.
- Cách Argo Rollouts chạy AnalysisRun.
- Cách Prometheus metric quyết định promote hoặc abort.
- Cách xác nhận stable version vẫn phục vụ traffic.

Vì sao phải học:

- Đây là failure mode thực tế của delivery pipeline.
- Canary không có analysis thì chỉ là rollout từng bước, chưa phải release guardrail đúng nghĩa.
- Rollback/abort cần dựa trên metric, không dựa vào cảm giác.

Liên quan tới yêu cầu tuần:

- W9 đã học canary và observability.
- W10 cần tích hợp nó với security và runbook.

## 6. Runbook cần học gì và vì sao

### 6.1. Incident response flow

Cần học:

- Detect.
- Triage.
- Contain.
- Eradicate.
- Recover.
- Post-mortem.

Vì sao phải học:

- Khi sự cố xảy ra, cần thứ tự hành động rõ.
- Nếu xóa ngay tài nguyên bị nghi compromise, có thể mất evidence.
- Nếu chỉ điều tra mà không contain, sự cố có thể lan rộng.

Liên quan tới yêu cầu tuần:

- Live mentor có Incident Response on AWS.
- D3 yêu cầu runbook template.

### 6.2. Runbook pod compromised

Cần học:

- Cách xác định pod, image, node, namespace.
- Cách lấy log, event và manifest.
- Cách cô lập bằng NetworkPolicy, scale down hoặc block traffic.
- Khi nào giữ evidence, khi nào ưu tiên dập sự cố.

Vì sao phải học:

- Container/K8s security không chỉ là chặn trước, mà còn phải phản ứng khi bị compromise.
- Pod compromised là tình huống trực tiếp nối Day A và Day B.

Liên quan tới yêu cầu tuần:

- Live mentor hỏi "khi cluster K8s bị compromise: làm gì 5 phút đầu?"
- Lab cần runbook có thể thực hành.

### 6.3. Runbook rollout failed

Cần học:

- Cách xem Rollout, ReplicaSet, AnalysisRun.
- Cách kiểm tra Prometheus query.
- Cách abort hoặc rollback.
- Cách xác nhận traffic đang về stable version.

Vì sao phải học:

- Delivery failure là sự cố vận hành thường gặp.
- Không nên promote thủ công nếu chưa hiểu analysis fail vì app lỗi hay metric lỗi.

Liên quan tới yêu cầu tuần:

- W9 canary trở thành một phần mini platform W10.
- Day C cần chứng minh platform vận hành được, không chỉ deploy được.

### 6.4. Runbook secret rotation failed

Cần học:

- Cách kiểm tra AWS secret version.
- Cách kiểm tra IAM permission của ESO.
- Cách kiểm tra ExternalSecret condition.
- Cách kiểm tra Kubernetes Secret đã update chưa.
- Cách kiểm tra app có reload secret hay không.

Vì sao phải học:

- Secret rotation có nhiều lớp, lỗi ở lớp nào cũng có triệu chứng giống nhau là app không nhận secret mới.
- Runbook giúp debug theo lớp thay vì đoán.

Liên quan tới yêu cầu tuần:

- Day B yêu cầu secret rotate dưới 60 giây.
- Day C biến yêu cầu đó thành quy trình vận hành khi fail.

## 7. Vì sao Day C nằm sau Day A và Day B

Day A trả lời:

- Ai được quyền làm gì?
- Manifest nào bị chặn?

Day B trả lời:

- Secret đến từ đâu?
- Image có đáng tin không?

Day C trả lời:

- Tất cả thứ đó có chạy cùng nhau không?
- Khi lỗi thì xử lý thế nào?
- Có kiểm soát tài nguyên và chi phí không?
- Có thể tái dựng platform từ repo không?

Nếu thiếu Day C, các phần trước chỉ là bài tập rời rạc. Day C biến chúng thành một platform có thể bàn giao cho capstone.

## 8. Kết nối với mục tiêu cuối W10

Day C liên quan trực tiếp tới các mục tiêu:

- Tích hợp toàn stack W8 -> W10.
- ResourceQuota + LimitRange.
- Chaos test.
- Runbook template.
- AWS Cost Anomaly Detection.
- Mini platform end-to-end deploy từ repo trong dưới 2 giờ.

Day C cũng là bước chuẩn bị cuối trước lab onsite:

- Lab cleanup cần biết dependency giữa RBAC, policy, secret, image verification và observability.
- Show-and-tell cần demo được flow, không chỉ đọc manifest.
- W11-W12 capstone cần platform nền đủ ổn định để team khác dùng.

Tóm lại, Day C dạy cách nghĩ như platform engineer: không chỉ cài tool, mà phải làm cho tool phối hợp được, có guardrail, có evidence, có runbook và có khả năng tái dựng.
