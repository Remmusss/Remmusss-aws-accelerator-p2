# W9 Day A - GitOps và CI/CD

## Mục tiêu học

Sau ngày này cần nắm được:

- GitOps là gì, tại sao W9 chuyển từ `kubectl apply` thủ công sang agent kéo state từ Git.
- Cách tách vai trò giữa CI và CD trong bài toán Kubernetes.
- Cách dùng GitHub Actions để làm `plan-on-PR` và `apply-on-merge`.
- Khi nào nên dùng Argo CD, khi nào Flux là lựa chọn thay thế hợp lý.
- Cách tổ chức repo theo `app-of-apps` hoặc `ApplicationSet`.
- Cách dùng sync phases / sync waves để ép thứ tự rollout resource.
- Khác nhau giữa rollback bằng `git revert` và `kubectl rollout undo`.

## Ý tưởng cốt lõi cần học trước

### 1. GitOps dùng source of truth nào?

OpenGitOps định nghĩa 4 nguyên lý cốt lõi:

- `Declarative`: desired state phải được mô tả khai báo.
- `Versioned and Immutable`: state được lưu có version và lịch sử thay đổi rõ ràng.
- `Pulled Automatically`: software agent tự động kéo desired state.
- `Continuously Reconciled`: agent liên tục đối chiếu actual state với desired state và sửa drift.

Ý nghĩa thực tế cho W9:

- Không deploy bằng lệnh tay là luồng chính nữa.
- Git là nơi duyệt thay đổi, audit, rollback.
- Cluster được agent Argo CD hoặc Flux đồng bộ từ repo.

## CI và CD trong bài toán W9

### CI cần làm gì

CI bằng GitHub Actions nên xử lý các bước:

- validate YAML, Helm, Kustomize, policy
- build image nếu có source app
- test, lint, security scan nếu bài lab cần thêm
- trên pull request: chạy check để xem thay đổi có an toàn không

GitHub Actions workflow là YAML trong `.github/workflows`, được kích hoạt bởi event như `pull_request`, `push`, `workflow_dispatch`, `workflow_run`.

### CD cần làm gì

Với Argo CD, CI không push trực tiếp vào cluster. Luồng đúng là:

1. CI build image mới.
2. CI cập nhật manifest hoặc Helm values trong repo cấu hình.
3. CI `git commit` và `git push`.
4. Argo CD detect commit mới và sync cluster theo desired state.

Đây là khác biệt quan trọng giữa push-based CD và GitOps pull-based CD.

## Argo CD: những ý cần nắm

### 1. Vì sao Argo CD hợp với mục tiêu W9

Argo CD phù hợp khi cần:

- quản lý desired state của ứng dụng Kubernetes bằng Git
- so sánh `live` và `desired`
- tự động sync và tự phục hồi drift
- quản lý nhiều app, nhiều namespace, nhiều environment

### 2. App of Apps và ApplicationSet

Hai pattern cần biết:

- `App of Apps`: một `Application` cha quản lý nhiều `Application` con. Hợp khi muốn bootstrap platform stack.
- `ApplicationSet`: controller tạo nhiều `Application` từ template + generator. Hợp khi cần multi-cluster, multi-env, monorepo.

Gợi ý cho W9:

- Nếu bài lab cần bootstrap cả platform, có thể đặt `argocd/root-app.yaml` trỏ vào `apps/`.
- Nếu cần render nhiều app theo env, tìm hiểu thêm `ApplicationSet` generator `list`, `cluster`, `git`.

### 3. Sync phases và sync waves

Argo CD có 3 phase mức cao:

- `PreSync`
- `Sync`
- `PostSync`

Trong mỗi phase có thể chia thêm `wave` bằng annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```

Ứng dụng thực tế:

- wave thấp cho CRD, namespace, config chung
- wave cao hơn cho app deployment
- PostSync cho smoke check, notification, hook

### 4. Automation from CI pipelines

Điểm cần nhớ:

- repo manifest nên tách riêng repo app source nếu dự án lớn hoặc muốn giữ ranh giới rõ
- CI cập nhật image tag trong manifest
- commit vào Git, để Argo CD lo phần sync

## Flux là gì, so nhanh để biết

Flux cũng là một công cụ GitOps cho Kubernetes:

- giữ cluster đồng bộ với Git
- tự reconcile liên tục
- hỗ trợ multi-tenancy và nhiều repo

Cạnh tranh với Argo CD ở lớp GitOps/CD. Trong W9 nên học Flux ở mức:

- hiểu nó cũng giải bài toán GitOps
- biết điểm khác: Argo CD nổi trội ở UX/UI app-centric; Flux có xu hướng toolkit/controller-centric
- không cần chia thời gian sâu nếu lab chính dùng Argo CD

## Rollback: `git revert` vs `kubectl rollout undo`

### `git revert`

Nên ưu tiên trong GitOps vì:

- desired state được sửa ngay tại source of truth
- có audit trail rõ ràng
- Argo CD sẽ reconcile về commit đã revert

### `kubectl rollout undo`

Chỉ là thao tác trên live cluster:

- có thể giải quyết nhanh sự cố tức thời
- nhưng nếu manifest trong Git không đổi, agent GitOps có thể đồng bộ lại version lỗi

Kết luận:

- rollback chính thống trong GitOps là `git revert`
- `kubectl rollout undo` chỉ nên xem là biện pháp cấp cứu, sau đó phải đồng bộ lại Git

## Lộ trình học để xong Day A

1. Đọc 4 nguyên lý OpenGitOps để hiểu triết lý.
2. Đọc GitHub Actions về workflow syntax và trigger events.
3. Đọc Argo CD `Getting Started`, `Automation from CI Pipelines`, `Sync Phases and Waves`.
4. Đọc `ApplicationSet` để biết khi nào cần automation nhiều app.
5. Đọc nhanh Flux để có góc nhìn so sánh.
6. Vẽ lại luồng W9 của chính bạn bằng sơ đồ:
   `PR -> GitHub Actions validate -> merge -> update manifests -> Argo CD sync`.

## Checklist tự kiểm tra

- Giải thích được 4 nguyên lý GitOps mà không cần nhìn tài liệu.
- Phân biệt rõ `build artifact` và `deploy artifact`.
- Viết được workflow GitHub Actions có `pull_request` và `push`.
- Giải thích khi nào cần `sync-wave`.
- Biết vì sao `git revert` đúng hơn `kubectl rollout undo` trong GitOps.
- Biết lúc nào dùng `App of Apps`, lúc nào nghiêng về `ApplicationSet`.

## Cấu trúc repo nên có cho W9

```text
cloud/w9/day-a/
  learning-guide.md
  .github/workflows/
  argocd/
    root-app.yaml
    apps/
```

## Nguồn tài liệu gốc

- Argo CD overview: https://argo-cd.readthedocs.io/en/stable/
- Argo CD CI automation: https://argo-cd.readthedocs.io/en/latest/user-guide/ci_automation/
- Argo CD sync waves: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-waves/
- Argo CD ApplicationSet: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/
- GitHub Actions workflows: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows
- GitHub Actions triggers: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- OpenGitOps principles: https://opengitops.dev
- Flux docs: https://fluxcd.io/flux
