# W10 Day B - Secrets Rotation + Supply Chain Security

## 1. Mục tiêu cần đạt được

Ngày B tập trung vào hai nhóm rủi ro rất hay gặp trong platform Kubernetes:

- Secret bị hardcode, copy tay, không rotate được.
- Image/container artifact không được scan, không được ký, và cluster chấp nhận image không rõ nguồn gốc.

Kết quả cuối ngày cần đạt:

- Secret thật nằm trong AWS Secrets Manager, không commit vào Git.
- Kubernetes Secret được đồng bộ bằng External Secrets Operator.
- Secret rotate và workload nhận giá trị mới trong vòng dưới 60 giây.
- Pipeline có Trivy scan image.
- Image được ký bằng Cosign.
- Admission policy từ chối image chưa ký hoặc không khớp policy.
- Có exception policy cho CVE, có lý do và thời hạn.

Mục tiêu quan trọng là chứng minh supply chain không dừng ở CI. CI scan/sign là cần thiết, nhưng cluster admission mới là chốt chặn cuối trước khi workload chạy.

## 2. Cần làm những gì

### 2.1. Tạo cấu trúc thư mục

Nên tổ chức Day B như sau:

```text
cloud/w10/day-b/
  eso/
    namespace.yaml
    serviceaccount.yaml
    secretstore.yaml
    externalsecret.yaml
    sample-app.yaml
  signing/
    cosign-keyless.md
    cosign-keybased.md
    verify-policy.yaml
  ci-trivy/
    github-actions-example.yaml
    trivy-policy.md
  exceptions/
    cve-exception-template.md
  evidence/
    eso-rotation.md
    trivy-scan.md
    cosign-sign-verify.md
    admission-reject.md
  system.md
```

Lý do:

- `eso/` dành cho secret runtime.
- `ci-trivy/` dành cho bước kiểm tra trước khi build/deploy.
- `signing/` dành cho provenance/signature.
- `exceptions/` bắt buộc tách riêng để tránh biến exception thành "bỏ qua lỗi vĩnh viễn".

### 2.2. Thiết kế secret flow

Luồng cần đạt:

```text
AWS Secrets Manager
  -> External Secrets Operator
  -> Kubernetes Secret
  -> Pod env hoặc mounted file
```

Không nên dùng flow:

```text
.env local -> kubectl create secret -> commit manifest hoặc copy tay
```

Lý do:

- AWS Secrets Manager có versioning, rotation, IAM access control và audit qua CloudTrail.
- ESO biến secret manager thành nguồn truth bên ngoài cluster.
- Kubernetes Secret chỉ là bản materialized để pod dùng, không phải nơi quản trị secret gốc.

### 2.3. Công nghệ chọn: AWS Secrets Manager

Chọn AWS Secrets Manager cho secret gốc.

Setting đề xuất:

```text
secret name: /w10/dev/demo-api
region: us-west-2
format: JSON
keys:
  username
  password
  apiKey
```

Lý do chọn JSON:

- Một secret có thể chứa nhiều key liên quan cùng ứng dụng.
- ESO map từng property sang từng key trong Kubernetes Secret dễ dàng.
- Dễ rotate một object logic thay vì nhiều secret rời rạc.

Lý do chọn prefix `/w10/dev/...`:

- Dễ phân biệt environment.
- IAM policy có thể giới hạn theo prefix.
- Audit và cleanup sau lab dễ hơn.

### 2.4. Công nghệ chọn: External Secrets Operator

Chọn ESO để đồng bộ secret từ AWS Secrets Manager vào Kubernetes.

Lý do:

- ESO là Kubernetes-native, khai báo bằng CRD `SecretStore` và `ExternalSecret`.
- Phù hợp GitOps vì manifest chỉ chứa reference, không chứa secret value.
- Có `refreshInterval` để kiểm soát tốc độ cập nhật.
- Hỗ trợ nhiều backend nếu sau này đổi sang Parameter Store, Vault, GCP Secret Manager.

Setting quan trọng:

```yaml
refreshInterval: 30s
target:
  creationPolicy: Owner
```

Lý do chọn `refreshInterval: 30s`:

- Yêu cầu W10 là rotate secret dưới 60 giây.
- 30 giây đủ nhanh để demo rõ ràng.
- Không quá thấp để tránh gọi AWS Secrets Manager quá dày trong lab.

Lý do chọn `creationPolicy: Owner`:

- ESO sở hữu Kubernetes Secret được tạo ra.
- Khi xóa ExternalSecret, Secret liên quan có thể được dọn theo controller ownership.
- Giảm rủi ro Secret mồ côi sau lab.

### 2.5. Chọn cơ chế AWS auth cho ESO

Trong lab local/minikube hiện tại, ESO dùng Kubernetes Secret `aws-credentials` và `SecretStore.auth.secretRef` để đọc AWS Secrets Manager. Secret này được tạo từ AWS profile local và không commit vào Git.

Nếu chạy trên EKS production-style, ưu tiên IRSA hoặc EKS Pod Identity.

Quyền IAM tối thiểu:

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:<region>:<account-id>:secret:/w10/dev/*"
}
```

Lý do:

- ESO chỉ cần đọc secret, không cần quyền tạo/sửa/xóa secret.
- Giới hạn resource theo prefix `/w10/dev/*` để tránh ESO đọc secret ngoài phạm vi lab.
- IRSA/EKS Pod Identity tốt hơn static AWS keys trong production vì credential không nằm trong pod manifest hoặc Kubernetes Secret.

Nếu dùng cluster local, có thể dùng static credential tạm thời trong Secret riêng cho lab, nhưng phải ghi rõ đây không phải production-grade. Credential đó không được commit.

### 2.6. Thiết kế sample app kiểm tra rotation

Ứng dụng mẫu cần chứng minh secret đổi mà không restart pod.

Cách tốt nhất:

- Mount Kubernetes Secret dưới dạng volume file.
- App đọc file theo từng request hoặc có watcher reload định kỳ.
- Không chỉ dùng environment variable.

Lý do:

- Env var từ Secret chỉ được inject khi container start.
- Khi Kubernetes Secret thay đổi, env var trong process không tự đổi.
- Secret volume được kubelet cập nhật theo thời gian, phù hợp mục tiêu no-restart.

Setting đề xuất:

```yaml
volumes:
  - name: app-secret
    secret:
      secretName: demo-api-secret
containers:
  - name: app
    volumeMounts:
      - name: app-secret
        mountPath: /var/run/secrets/demo
        readOnly: true
```

Kiểm thử:

1. Gọi endpoint hiển thị hash hoặc version của secret, không in plain secret.
2. Update secret value trong AWS Secrets Manager.
3. Đợi dưới 60 giây.
4. Gọi lại endpoint, hash/version phải thay đổi.
5. Kiểm tra pod không restart:

```powershell
kubectl -n app-dev get pod
kubectl -n app-dev describe pod <pod-name>
```

Không in secret thật trong evidence. Chỉ in hash, timestamp, version id hoặc masked value.

## 3. Supply chain security cần triển khai

### 3.1. Trivy scan trong CI

Chọn Trivy để scan image.

Lý do:

- Dễ dùng trong GitHub Actions.
- Scan được OS package, language package, config và secret tùy mode.
- Phổ biến, có output table/json/sarif.
- Phù hợp lab vì setup nhanh nhưng vẫn thực tế.

Policy đề xuất:

```text
Fail CI nếu có CRITICAL.
Fail CI nếu có HIGH mà không có exception.
MEDIUM/LOW ghi nhận trong report.
Ignore unfixed tùy bài lab, nhưng phải giải thích.
```

Setting mẫu:

```text
trivy image --severity HIGH,CRITICAL --exit-code 1 --ignore-unfixed <image>
```

Lý do chọn fail HIGH/CRITICAL:

- Đây là ngưỡng hợp lý cho lab security.
- Không biến pipeline thành noise vì MEDIUM/LOW quá nhiều.
- Buộc người học xử lý lỗi có rủi ro cao.

Lý do cân nhắc `--ignore-unfixed`:

- Một số CVE chưa có bản vá, fail pipeline liên tục không tạo giá trị.
- Nếu bật, phải có báo cáo CVE chưa fix để theo dõi.
- Nếu tắt, phải có exception policy rõ.

### 3.2. Exception policy cho CVE

Mỗi exception phải có:

```text
CVE ID
image/package affected
severity
reason
compensating control
owner
expiry date
link ticket/ADR
```

Lý do:

- Exception không phải bỏ qua vĩnh viễn.
- Có owner và expiry buộc revisit.
- Compensating control giúp chứng minh vẫn quản trị rủi ro.

Không chấp nhận exception dạng "lab nên bỏ qua" nếu không có thời hạn.

### 3.3. Cosign signing

Cần thực hành cả hai hướng:

- Keyless signing bằng OIDC.
- Key-based signing bằng key pair.

Keyless phù hợp GitHub Actions vì dùng OIDC identity của workflow.

Lý do chọn keyless:

- Không phải quản lý private key dài hạn.
- Signature gắn với identity của CI workflow.
- Phù hợp Sigstore/Fulcio/Rekor.

Key-based phù hợp môi trường không dùng được public OIDC hoặc cần key nội bộ.

Lý do vẫn học key-based:

- Nhiều enterprise còn yêu cầu quản lý key riêng.
- Giúp hiểu trade-off giữa key custody và keyless identity.

Setting quan trọng:

```text
image tag nên immutable theo commit SHA
không ký tag latest
nên verify theo digest hoặc tag immutable
```

Lý do:

- Ký `latest` không đảm bảo artifact ổn định.
- Digest là định danh nội dung image chính xác nhất.
- Commit SHA giúp trace image về source revision.

### 3.4. Admission verify signature

Admission verify signature có thể dùng Kyverno `verifyImages` hoặc policy controller tương đương.

Trong W10, nếu Day A đã dùng Gatekeeper cho policy cấu hình, Day B có thể dùng Kyverno cho image verification vì Kyverno hỗ trợ verify image signature thuận tiện hơn Gatekeeper thuần Rego.

Lý do chọn Kyverno cho verify image:

- Có policy `verifyImages` thiết kế sẵn cho use case này.
- Tích hợp Cosign tốt.
- Dễ demo admission reject unsigned image.
- Policy YAML dễ đọc với người mới hơn tự viết Rego verify signature.

Policy mong muốn:

- Chỉ cho phép image từ registry đã định.
- Bắt buộc image có signature hợp lệ.
- Verify identity issuer/subject nếu dùng keyless.
- Reject image unsigned.
- Có namespace exclude cho system namespace.

Setting cần chú ý:

```text
validationFailureAction: Enforce
background: true
failurePolicy: Fail nếu muốn strict, Ignore nếu ưu tiên availability
```

Chọn `Enforce` cho mục tiêu W10 vì yêu cầu admission reject unsigned image.

`failurePolicy` nên giải thích trade-off:

- `Fail`: nếu policy webhook lỗi thì reject request, bảo mật hơn nhưng có thể ảnh hưởng deploy.
- `Ignore`: nếu webhook lỗi thì cho qua, availability tốt hơn nhưng có khoảng trống bảo mật.

Trong lab hardening, chọn `Fail` nếu cluster ổn định. Nếu local cluster hay lỗi webhook, có thể chọn `Ignore` khi học, nhưng trạng thái cuối nên chứng minh được reject unsigned image.

## 4. Thiết lập ban đầu

### 4.1. Công cụ cần có

Cần có:

- AWS CLI đã login đúng account.
- `kubectl`.
- `helm`.
- `docker` hoặc build tool tương đương.
- `trivy`.
- `cosign`.
- GitHub Actions nếu dùng CI remote.

Kiểm tra:

```powershell
aws sts get-caller-identity
kubectl get nodes
helm version
trivy --version
cosign version
```

### 4.2. Tạo secret trong AWS Secrets Manager

Ví dụ:

```powershell
aws secretsmanager create-secret `
  --region us-west-2 `
  --name /w10/dev/demo-api `
  --secret-string '{"username":"demo","password":"initial-password","apiKey":"initial-key"}'
```

Khi rotate:

```powershell
aws secretsmanager put-secret-value `
  --region us-west-2 `
  --secret-id /w10/dev/demo-api `
  --secret-string '{"username":"demo","password":"rotated-password","apiKey":"rotated-key"}'
```

Không đưa giá trị thật vào evidence. Dùng masked output hoặc version id.

### 4.3. Cài External Secrets Operator

```powershell
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets `
  --namespace external-secrets `
  --create-namespace `
  --set installCRDs=true
```

Lý do `installCRDs=true`:

- ESO cần CRD như `SecretStore`, `ClusterSecretStore`, `ExternalSecret`.
- Cài bằng Helm đồng bộ controller và CRD.

Kiểm tra:

```powershell
kubectl -n external-secrets get pods
kubectl get crd | Select-String external-secrets
```

### 4.4. Tạo `SecretStore` và `ExternalSecret`

`SecretStore` nên scoped theo namespace nếu chỉ dùng cho một app:

```yaml
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: app-dev
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
```

Lý do dùng `SecretStore` thay vì `ClusterSecretStore`:

- Scope hẹp hơn, dễ kiểm soát hơn trong lab.
- Giảm rủi ro một namespace đọc secret của namespace khác.

`ExternalSecret`:

```yaml
kind: ExternalSecret
metadata:
  name: demo-api-secret
  namespace: app-dev
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: demo-api-secret
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: /w10/dev/demo-api
        property: username
    - secretKey: password
      remoteRef:
        key: /w10/dev/demo-api
        property: password
```

## 5. Evidence cần nộp

Evidence tối thiểu:

- `kubectl get externalsecret -n app-dev`.
- `kubectl describe externalsecret demo-api-secret -n app-dev` cho thấy sync thành công.
- Log hoặc timestamp chứng minh secret update dưới 60 giây.
- Pod không restart khi secret đổi.
- Trivy scan output hoặc GitHub Actions summary.
- Cosign sign và verify output.
- Admission reject image unsigned.
- Exception template nếu có CVE bị chấp nhận tạm thời.

## 6. Tiêu chí hoàn thành

Day B hoàn thành khi:

- Secret không nằm trong Git.
- ESO đồng bộ được Secret từ AWS Secrets Manager.
- Rotate secret dưới 60 giây và workload đọc được giá trị mới không restart.
- CI có Trivy scan với ngưỡng rõ ràng.
- Image được ký bằng Cosign.
- Cluster reject unsigned image.
- Có giải thích rõ vì sao chọn AWS Secrets Manager, ESO, Trivy, Cosign, Kyverno/Gatekeeper policy và các setting quan trọng.

## 7. Artifact thuc te trong repo

Day B hien co cac file trien khai sau:

- `.gitignore`: chan `.env`, private key Cosign, report va output local.
- `eso/namespace.yaml`: namespace `app-dev`.
- `eso/serviceaccount.yaml`: ServiceAccount `eso-reader`; local/minikube auth dùng Secret `aws-credentials`, không dùng IRSA annotation.
- `eso/secretstore.yaml`: ESO `SecretStore` trỏ tới AWS Secrets Manager ở `us-west-2`.
- `eso/externalsecret.yaml`: sync `/w10/dev/demo-api` sang Kubernetes Secret `demo-api-secret` voi `refreshInterval: 30s`.
- `eso/sample-app.yaml`: app Python doc secret tu mounted volume va tra hash, khong in secret that.
- `signing/cosign-keyless.md`: huong dan keyless signing OIDC.
- `signing/cosign-keybased.md`: huong dan key-based signing va canh bao khong commit private key.
- `signing/verify-policy.yaml`: Kyverno ClusterPolicy verify image signature bang Cosign.
- `ci-trivy/github-actions-example.yaml`: workflow mau build, Trivy scan, push, Cosign sign.
- `ci-trivy/trivy-policy.md`: policy fail HIGH/CRITICAL.
- `exceptions/cve-exception-template.md`: template exception co owner va expiry.
- `evidence/`: checklist cho ESO rotation, Trivy, Cosign, admission reject.
- `kustomization.yaml`: entrypoint render/apply Day B.
