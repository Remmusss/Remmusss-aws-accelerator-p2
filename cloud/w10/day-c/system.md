# W10 Day C - Platform Integration + Runbook + Cost Guard

## 1. Mục tiêu cần đạt được

Ngày C là ngày ghép toàn bộ stack W8 -> W10 thành một mini platform end-to-end. Mục tiêu không phải cài thêm thật nhiều tool, mà là chứng minh platform có thể bootstrap, vận hành, quan sát, bảo vệ và kiểm soát chi phí theo một luồng nhất quán.

Kết quả cuối ngày cần đạt:

- Fresh cluster có thể được bootstrap từ repo trong dưới 2 giờ.
- GitOps, observability, canary rollout, RBAC, admission policy, secret sync và image verification hoạt động cùng nhau.
- Namespace ứng dụng có `ResourceQuota` và `LimitRange`.
- Có cost guard ở AWS bằng Cost Anomaly Detection.
- Có chaos test nhỏ để kiểm tra khả năng phục hồi.
- Có runbook xử lý sự cố theo mẫu rõ ràng.
- Có evidence cho luồng end-to-end.

Trọng tâm là tích hợp: mọi phần đã học phải nối được với nhau thành một platform có thể bàn giao cho W11-W12 capstone.

## 2. Cần làm những gì

### 2.1. Tạo cấu trúc thư mục

Nên tổ chức Day C như sau:

```text
cloud/w10/day-c/
  platform-bootstrap/
    README.md
    prerequisites.md
    bootstrap-order.md
    argocd-apps/
    namespaces/
    quotas/
    policies/
  runbooks/
    incident-response-template.md
    pod-compromised.md
    rollout-failed.md
    secret-rotation-failed.md
    cost-anomaly.md
  chaos/
    pod-delete-test.md
    network-or-latency-test.md
  cost-guard/
    cost-anomaly-detection.md
    tagging-standard.md
  evidence/
    bootstrap-timing.md
    quota-tests.md
    chaos-test.md
    runbook-drill.md
  system.md
```

Lý do:

- `platform-bootstrap/` mô tả cách dựng lại platform từ đầu.
- `runbooks/` là tài liệu vận hành khi có sự cố.
- `chaos/` tách riêng các thử nghiệm phá hỏng có kiểm soát.
- `cost-guard/` tách khỏi Kubernetes manifest vì AWS billing không nằm trong cluster.

### 2.2. Xác định luồng platform end-to-end

Luồng tích hợp cần chứng minh:

```text
Git commit
  -> Argo CD sync
  -> workload deploy bằng rollout/canary
  -> image đã scan và ký
  -> admission policy kiểm tra manifest và signature
  -> secret lấy từ AWS Secrets Manager qua ESO
  -> Prometheus scrape metric
  -> alert/runbook xử lý khi lỗi
  -> ResourceQuota/LimitRange kiểm soát tài nguyên
  -> cost anomaly cảnh báo bất thường ở AWS
```

Mục tiêu là khi thay đổi app hoặc platform config, trạng thái mong muốn vẫn đi qua Git và các guardrail tự động.

### 2.3. Bootstrap order

Thứ tự bootstrap đề xuất:

1. Cluster nền: local cluster hoặc EKS sandbox.
2. Namespace hệ thống: `argocd`, `monitoring`, `gatekeeper-system`, `external-secrets`, `kyverno`, `app-dev`.
3. Argo CD.
4. Policy controller: Gatekeeper và Kyverno nếu dùng cả hai.
5. External Secrets Operator.
6. Monitoring stack: kube-prometheus-stack.
7. Argo Rollouts.
8. Platform policies: RBAC, Gatekeeper constraints, verify image policies.
9. App workloads.
10. Smoke test và evidence.

Lý do thứ tự này:

- CRD/controller phải có trước custom resource.
- Policy controller nên có trước app để chặn lỗi từ đầu.
- ESO phải có trước workload cần Secret.
- Monitoring và Rollouts phải có trước khi chạy canary có analysis.
- App deploy sau cùng để được bảo vệ bởi toàn bộ guardrail.

### 2.4. App-of-Apps cho platform

Nên dùng Argo CD App-of-Apps cho platform bootstrap.

Lý do:

- Một root app có thể quản lý nhiều app con.
- Dễ tái dựng fresh cluster.
- Có thể tách ownership theo app: monitoring, rollouts, policies, secrets, workloads.
- Dễ kiểm tra app nào fail khi bootstrap.

Setting cho root app:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

Lý do:

- `prune: true` dọn resource bị xóa khỏi Git.
- `selfHeal: true` sửa drift khi ai sửa trực tiếp trong cluster.
- `CreateNamespace=true` giảm lỗi thiếu namespace khi bootstrap.

Với app chứa CRD hoặc chart phức tạp, cân nhắc:

```yaml
syncOptions:
  - ServerSideApply=true
```

Lý do:

- CRD và resource do controller mutate thường ổn định hơn với server-side apply.
- Giảm lỗi field ownership khi nhiều controller cùng chạm vào object.

## 3. ResourceQuota và LimitRange

### 3.1. Mục tiêu cost guard trong Kubernetes

`ResourceQuota` và `LimitRange` không thay thế AWS billing control, nhưng là lớp bảo vệ ngay trong namespace:

- Chặn namespace tạo quá nhiều pod.
- Bắt buộc workload có request/limit hợp lý.
- Giảm nguy cơ một app chiếm hết node.
- Làm nền cho capacity planning và cost attribution.

### 3.2. ResourceQuota đề xuất cho `app-dev`

Setting mẫu:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: app-dev-quota
  namespace: app-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "20"
    services: "10"
    secrets: "20"
    configmaps: "20"
```

Lý do:

- `requests.cpu/memory` kiểm soát tài nguyên scheduler cam kết.
- `limits.cpu/memory` chặn workload dùng quá mức.
- `pods` tránh scale nhầm quá nhiều replica.
- `services`, `secrets`, `configmaps` tránh namespace bị spam resource.

Giá trị này phù hợp lab nhỏ. Với production, phải lấy từ capacity thực tế, SLO, workload profile và budget.

### 3.3. LimitRange đề xuất

Setting mẫu:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: app-dev-defaults
  namespace: app-dev
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 500m
        memory: 512Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: "1"
        memory: 1Gi
```

Lý do:

- `defaultRequest` giúp pod thiếu request vẫn có baseline.
- `default` giúp pod thiếu limit không chạy vô hạn.
- `min` tránh khai báo quá thấp gây scheduling/SLO không thực tế.
- `max` chặn một container đơn lẻ chiếm quá nhiều tài nguyên namespace.

### 3.4. Kiểm thử quota

Test cần có:

- Pod hợp lệ có request/limit trong ngưỡng.
- Pod vượt memory limit bị reject.
- Deployment scale vượt số pod quota bị reject.
- Workload thiếu resource vẫn được default bởi LimitRange hoặc bị Gatekeeper reject tùy policy.

Lệnh kiểm tra:

```powershell
kubectl -n app-dev describe resourcequota app-dev-quota
kubectl -n app-dev describe limitrange app-dev-defaults
kubectl -n app-dev get pods
```

## 4. Chaos test

### 4.1. Công nghệ chọn

Với lab W10, ưu tiên chaos test đơn giản bằng `kubectl` trước, sau đó mới dùng Litmus hoặc Chaos Mesh nếu còn thời gian.

Lý do:

- Mục tiêu là chứng minh platform biết phát hiện và phục hồi lỗi cơ bản.
- `kubectl delete pod` dễ hiểu, ít phụ thuộc tool.
- Litmus/Chaos Mesh phù hợp khi muốn chuẩn hóa chaos experiment, nhưng thêm CRD/controller sẽ tăng độ phức tạp.

### 4.2. Pod delete test

Kịch bản:

1. Deploy app có `replicas: 2` trở lên.
2. Xóa một pod.
3. Kiểm tra ReplicaSet/Rollout tạo pod mới.
4. Kiểm tra service vẫn có endpoint.
5. Kiểm tra Prometheus có metric downtime hoặc không.

Lệnh:

```powershell
kubectl -n app-dev get pods
kubectl -n app-dev delete pod <pod-name>
kubectl -n app-dev get pods -w
kubectl -n app-dev get endpoints
```

Kết quả mong muốn:

- Pod mới được tạo.
- App không mất toàn bộ availability nếu còn replica khác.
- Alert không fire nếu downtime quá ngắn, hoặc fire đúng nếu vượt ngưỡng.

### 4.3. Canary failure test

Kịch bản:

1. Deploy version mới có lỗi giả lập.
2. Argo Rollouts đưa traffic canary.
3. Prometheus analysis fail.
4. Rollout abort.
5. Stable version vẫn phục vụ traffic.

Lý do:

- Đây là chaos test ở lớp release.
- Chứng minh W9 canary và W10 guardrail hoạt động cùng nhau.

## 5. Runbook

### 5.1. Mẫu runbook bắt buộc

Mỗi runbook nên có:

```text
Tên sự cố
Mức độ ảnh hưởng
Triệu chứng
Nguồn tín hiệu phát hiện
5 phút đầu cần làm gì
Lệnh kiểm tra
Cách cô lập
Cách khôi phục
Cách xác nhận đã khôi phục
Escalation
Postmortem notes
```

Lý do:

- Khi sự cố xảy ra, người trực không nên phải nghĩ từ đầu.
- Runbook giảm thời gian triage.
- Cấu trúc cố định giúp cả team đọc và thực thi giống nhau.

### 5.2. Runbook: pod compromised

5 phút đầu:

- Xác định namespace, pod, image, node.
- Thu thập log ngắn hạn.
- Chụp trạng thái pod YAML nếu cần evidence.
- Cô lập bằng NetworkPolicy hoặc scale workload xuống nếu cần.
- Không xóa ngay mọi thứ nếu cần giữ evidence, trừ khi đang gây hại.

Lệnh:

```powershell
kubectl -n <ns> get pod <pod> -o wide
kubectl -n <ns> logs <pod> --previous
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

Lý do:

- Cần cân bằng giữa containment và evidence.
- Node/pod/image giúp truy ngược supply chain.
- Event/log giúp biết lỗi do deploy, exploit hay misconfiguration.

### 5.3. Runbook: rollout failed

Các bước:

- Kiểm tra trạng thái Rollout.
- Kiểm tra AnalysisRun.
- Kiểm tra Prometheus query.
- Xác nhận stable version còn phục vụ traffic.
- Abort hoặc promote thủ công chỉ khi hiểu rõ lý do.

Lệnh:

```powershell
kubectl argo rollouts get rollout <name> -n <ns>
kubectl -n <ns> get analysisrun
kubectl -n <ns> describe analysisrun <name>
```

Lý do:

- Rollout fail có thể do app thật sự lỗi hoặc do metric/query sai.
- Không promote thủ công khi chưa xác định nguyên nhân.

### 5.4. Runbook: secret rotation failed

Các bước:

- Kiểm tra AWS secret version.
- Kiểm tra ExternalSecret condition.
- Kiểm tra Kubernetes Secret update time.
- Kiểm tra pod mount file có đổi không.
- Kiểm tra app reload behavior.

Lệnh:

```powershell
kubectl -n app-dev get externalsecret
kubectl -n app-dev describe externalsecret demo-api-secret
kubectl -n app-dev get secret demo-api-secret -o yaml
```

Lý do:

- Lỗi có thể nằm ở AWS IAM, ESO sync, Kubernetes secret projection hoặc app không reload.
- Tách từng lớp giúp debug nhanh hơn.

## 6. AWS Cost Anomaly Detection

### 6.1. Mục tiêu

Cost Anomaly Detection dùng để phát hiện chi phí AWS tăng bất thường, đặc biệt khi lab dùng EKS, NAT Gateway, Load Balancer, EBS volume hoặc log ingestion.

### 6.2. Thiết lập đề xuất

Tạo monitor:

```text
Monitor type: AWS services
Linked account: account lab
Alert threshold: absolute amount nhỏ phù hợp lab, ví dụ 5-10 USD
Frequency: daily
Subscriber: email cá nhân hoặc team email
```

Lý do:

- Lab thường có budget thấp, threshold cần nhỏ để phát hiện sớm.
- Daily đủ cho lab; production có thể cần alert nhanh hơn qua SNS.
- Theo AWS services giúp biết dịch vụ nào gây tăng chi phí.

### 6.3. Tagging standard

Tài nguyên AWS nên có tag:

```text
Project=W10
Owner=<student-name>
Environment=dev
CostCenter=training
TTL=<date>
```

Lý do:

- Cost allocation rõ hơn.
- Cleanup dễ hơn.
- `TTL` giúp biết tài nguyên lab nào cần xóa sau khi hoàn thành.

## 7. Evidence cần nộp

Evidence tối thiểu:

- Thời gian bootstrap fresh cluster, ghi start/end.
- Danh sách Argo CD apps Synced/Healthy.
- Output quota/limitrange.
- Test pod vượt quota bị reject.
- Chaos pod delete hoặc canary fail test.
- Một runbook drill đã thực hành.
- Screenshot hoặc mô tả Cost Anomaly Detection monitor.

## 8. Tiêu chí hoàn thành

Day C hoàn thành khi:

- Platform bootstrap được từ repo theo thứ tự rõ ràng.
- GitOps + observability + canary + RBAC + policy + ESO + image verification hoạt động cùng nhau.
- Namespace app có quota và limit range.
- Có ít nhất một chaos test có evidence.
- Có runbook đủ dùng khi sự cố xảy ra.
- Có cost guard ở AWS và tagging standard.
- Tài liệu giải thích vì sao chọn từng setting và trade-off khi áp dụng vào lab/production.

## 9. Artifact thuc te trong repo

Day C hien co cac file trien khai sau:

- `.gitignore`: chan log, screenshot va rendered artifact local.
- `platform-bootstrap/README.md`: mo ta luong end-to-end.
- `platform-bootstrap/prerequisites.md`: cong cu, controller va AWS setup can co.
- `platform-bootstrap/bootstrap-order.md`: thu tu bootstrap fresh cluster.
- `platform-bootstrap/namespaces/system-namespaces.yaml`: namespace he thong va `app-dev`.
- `platform-bootstrap/quotas/resourcequota.yaml`: ResourceQuota cho `app-dev`.
- `platform-bootstrap/quotas/limitrange.yaml`: LimitRange default/min/max cho container.
- `platform-bootstrap/policies/README.md`: cach tai su dung policy Day A va Day B.
- `platform-bootstrap/argocd-apps/`: root app va app con cho RBAC, policy, ESO, quota.
- `runbooks/`: template IR va runbook pod compromised, rollout failed, secret rotation failed, cost anomaly.
- `chaos/`: pod delete test va network/latency test guardrail.
- `cost-guard/`: Cost Anomaly Detection va tagging standard.
- `evidence/`: checklist bootstrap timing, quota test, chaos test, runbook drill.
- `kustomization.yaml`: entrypoint render/apply namespace va quota Day C.
