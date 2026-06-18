# W10 Day B - Learning Guide: Secrets Rotation + Supply Chain Security

## 1. Ngày này cần học gì

Day B cần học cách bảo vệ hai thứ rất nhạy trong platform Kubernetes:

- Secret runtime mà ứng dụng dùng để kết nối database, API, SMTP hoặc dịch vụ bên ngoài.
- Image/container artifact được build, scan, ký và chạy trong cluster.

Ngày này gồm hai mảng chính:

- Secrets Rotation: AWS Secrets Manager + External Secrets Operator.
- Supply Chain Security: Trivy + Cosign + admission verify signature.

Mục tiêu là hiểu toàn bộ đường đi từ secret/image source đến lúc workload chạy trong cluster, và biết đặt chốt kiểm soát ở đâu.

## 2. Secrets cần học gì và vì sao

### 2.1. Kubernetes Secret không phải secret manager hoàn chỉnh

Cần học:

- Kubernetes Secret là object trong cluster.
- Secret có thể được mount vào pod hoặc inject qua env.
- Secret trong Kubernetes mặc định là base64 encode, không phải encryption theo nghĩa ứng dụng.
- Secret có lifecycle gắn với cluster.

Vì sao phải học:

- Nhiều người nhầm base64 là bảo mật.
- Nếu commit Secret YAML vào Git, secret đã bị lộ.
- Nếu chỉ tạo secret bằng tay, khó audit, khó rotate, khó tái dựng cluster.

Liên quan tới yêu cầu tuần:

- W10 yêu cầu secret rotation với AWS Secrets Manager + ESO.
- Lab cần cleanup rủi ro secret bị hardcode hoặc quản lý thủ công.

### 2.2. AWS Secrets Manager

Cần học:

- Secret name, version, staging label như `AWSCURRENT`.
- Secret dạng string hoặc JSON.
- IAM policy giới hạn quyền đọc secret.
- CloudTrail có thể audit API call.

Vì sao phải học:

- AWS Secrets Manager là nguồn truth cho secret ngoài cluster.
- Có thể quản lý version và rotation tốt hơn Secret YAML.
- IAM giúp giới hạn ESO chỉ đọc đúng prefix secret cần thiết.

Liên quan tới yêu cầu tuần:

- Announcement W10 yêu cầu AWS Secrets Manager.
- Live mentor có phần AWS Security, IAM và IRSA.
- Secret rotation dưới 60 giây chỉ có ý nghĩa khi secret gốc được cập nhật từ nơi đáng tin.

### 2.3. External Secrets Operator

Cần học:

- ESO là controller đồng bộ secret từ backend bên ngoài vào Kubernetes.
- CRD chính: `SecretStore`, `ClusterSecretStore`, `ExternalSecret`.
- `refreshInterval` quyết định chu kỳ ESO kiểm tra secret mới.
- `target.creationPolicy` quyết định cách ESO quản lý Kubernetes Secret.

Vì sao phải học:

- GitOps không nên commit secret value.
- ESO cho phép commit reference tới secret, không commit secret thật.
- Khi secret ở AWS đổi, ESO tự cập nhật Kubernetes Secret.

Liên quan tới yêu cầu tuần:

- W10 yêu cầu ESO rotate secret dưới 60 giây.
- Day C cần tích hợp secret flow vào platform bootstrap.
- Lab cần chứng minh secret không còn quản lý thủ công.

### 2.4. `SecretStore` và `ClusterSecretStore`

Cần học:

- `SecretStore` scoped trong một namespace.
- `ClusterSecretStore` dùng được nhiều namespace.
- Cả hai đều mô tả backend provider và cách auth tới backend.

Vì sao phải học:

- Dùng scope sai có thể làm namespace này đọc secret của namespace khác.
- Lab nhỏ nên ưu tiên `SecretStore` để scope hẹp.
- Platform lớn có thể dùng `ClusterSecretStore` nhưng cần governance tốt.

Liên quan tới yêu cầu tuần:

- W10 hardening yêu cầu giảm quyền dư thừa.
- Scope secret store là một phần của least privilege.

### 2.5. IRSA hoặc EKS Pod Identity

Cần học:

- Pod cần AWS permission để ESO đọc Secrets Manager.
- IRSA/EKS Pod Identity gắn IAM role với Kubernetes ServiceAccount.
- IAM policy nên chỉ cho `secretsmanager:GetSecretValue` và `DescribeSecret` trên prefix cụ thể.

Vì sao phải học:

- Không nên đặt AWS access key tĩnh trong Kubernetes Secret.
- Static credential khó rotate và dễ lộ.
- IRSA/EKS Pod Identity phù hợp mô hình cloud-native trên EKS.

Liên quan tới yêu cầu tuần:

- Live mentor có IRSA.
- Day B dùng ESO với AWS backend.
- Lab cleanup cần loại bỏ static credential trong pod nếu có.

### 2.6. Secret rotation không restart

Cần học:

- Secret inject qua env var không tự cập nhật trong process đang chạy.
- Secret mount dạng volume có thể được kubelet cập nhật.
- App vẫn phải đọc lại file hoặc có reload mechanism.

Vì sao phải học:

- Yêu cầu W10 là secret rotate dưới 60 giây no-restart.
- Nếu app đọc secret một lần khi start, Kubernetes Secret có đổi cũng không giúp gì.
- Cần phân biệt secret đã sync vào cluster và app đã sử dụng secret mới.

Liên quan tới yêu cầu tuần:

- Đây là một mục tiêu cụ thể cuối W10.
- Evidence cần chứng minh pod không restart nhưng app thấy secret mới.

## 3. Supply chain cần học gì và vì sao

### 3.1. Container image lifecycle

Cần học:

- Image được build từ source.
- Image được push lên registry.
- Manifest Kubernetes tham chiếu image bằng tag hoặc digest.
- Kubelet pull image và chạy container.

Vì sao phải học:

- Security không chỉ nằm ở YAML Kubernetes.
- Nếu image đã chứa CVE hoặc bị thay thế, workload vẫn nguy hiểm dù manifest đúng.
- Cần biết chốt kiểm soát đặt ở CI, registry và admission.

Liên quan tới yêu cầu tuần:

- W10 có DevSecOps/Supply Chain Security.
- Lab yêu cầu reject unsigned image.

### 3.2. Image tag và digest

Cần học:

- Tag là nhãn có thể bị trỏ lại image khác.
- Digest là định danh theo nội dung image.
- `latest` là tag không tái lập được.

Vì sao phải học:

- GitOps cần desired state tái lập được.
- Ký hoặc verify image theo tag mutable có thể gây hiểu nhầm.
- Dùng commit SHA hoặc digest giúp trace image về source.

Liên quan tới yêu cầu tuần:

- Admission policy nên chặn `latest`.
- Cosign verify nên gắn với artifact cụ thể.

### 3.3. Trivy image scan

Cần học:

- Trivy scan CVE trong OS package và dependency.
- Có thể chọn severity như HIGH, CRITICAL.
- `exit-code 1` dùng để fail CI.
- Có thể xuất report để audit.

Vì sao phải học:

- CI phải phát hiện image có lỗ hổng trước khi deploy.
- Không có scan thì cluster có thể chạy image chứa CVE đã biết.
- Policy fail-on HIGH/CRITICAL giúp đặt ngưỡng rõ ràng.

Liên quan tới yêu cầu tuần:

- W10 yêu cầu Trivy image scan trong CI.
- Live mentor có phần Trivy CI scan policy.
- Lab cần evidence scan image.

### 3.4. CVE exception policy

Cần học:

- Exception phải có CVE ID, lý do, owner, expiry date.
- Exception cần compensating control.
- Exception không được là cách bỏ qua vĩnh viễn.

Vì sao phải học:

- Thực tế có CVE chưa có fix hoặc không exploitable trong ngữ cảnh app.
- Nếu không có quy trình exception, team sẽ hoặc block deploy vô lý, hoặc bỏ qua security vô kỷ luật.
- Expiry date buộc kiểm tra lại.

Liên quan tới yêu cầu tuần:

- Announcement W10 nhắc exception policy CVE.
- Đây là cầu nối giữa security nghiêm túc và vận hành thực tế.

### 3.5. Cosign signing

Cần học:

- Cosign dùng để ký image.
- Có hai cách chính: keyless OIDC và key-based.
- Signature có thể được verify trước hoặc trong admission.

Vì sao phải học:

- Scan chỉ nói image có CVE hay không, không chứng minh image đến từ pipeline đáng tin.
- Signing giúp xác nhận artifact được tạo bởi identity/key được tin cậy.
- Nếu attacker push image vào registry, admission verify có thể chặn nếu image không có signature đúng.

Liên quan tới yêu cầu tuần:

- W10 yêu cầu Cosign signing.
- Lab cần admission reject unsigned image.

### 3.6. Keyless OIDC signing

Cần học:

- Keyless signing dùng identity từ OIDC provider như GitHub Actions.
- Signature gắn với issuer và subject.
- Không cần lưu private key dài hạn.

Vì sao phải học:

- Giảm rủi ro mất private key.
- Phù hợp CI/CD hiện đại.
- Có thể ràng buộc image phải do workflow cụ thể ký.

Liên quan tới yêu cầu tuần:

- Announcement W10 nhắc Cosign keyless OIDC.
- Live mentor có verify signature ở CI/registry/admission.

### 3.7. Key-based signing

Cần học:

- Tạo key pair.
- Dùng private key để ký image.
- Dùng public key để verify.
- Cần bảo vệ private key.

Vì sao phải học:

- Một số môi trường enterprise chưa dùng keyless hoặc cần key nội bộ.
- Hiểu key-based giúp thấy trade-off của key custody.
- Có thể dùng cho lab local nếu chưa có OIDC workflow.

Liên quan tới yêu cầu tuần:

- Announcement W10 yêu cầu biết cả keyless và key-based.

### 3.8. Admission verify signature

Cần học:

- CI verify là chưa đủ vì người có quyền cluster có thể apply manifest trực tiếp.
- Admission verify kiểm tra image ngay khi workload được tạo/sửa.
- Kyverno `verifyImages` là cách thực tế để verify Cosign signature.

Vì sao phải học:

- Chốt chặn cuối cùng nằm ở Kubernetes API.
- Đây là cách đảm bảo "unsigned image không được chạy".
- Admission policy biến supply chain security thành cluster-level enforcement.

Liên quan tới yêu cầu tuần:

- Mục tiêu cuối W10 có "admission reject unsigned image".
- Lab T5-T6 cần chứng minh enforcement, không chỉ CI pass.

## 4. Vì sao Day B nằm sau Day A

Day A tạo nền:

- RBAC giới hạn ai được deploy.
- Gatekeeper chặn cấu hình workload nguy hiểm.

Day B bổ sung:

- Secret được lấy từ nguồn an toàn.
- Image được scan và ký.
- Admission chặn image không đáng tin.

Nếu thiếu Day A:

- Người có quyền quá rộng có thể bypass secret/supply-chain policy.

Nếu thiếu Day B:

- Cluster có thể vẫn chạy image độc hại hoặc dùng secret bị lộ dù RBAC đúng.

Vì vậy Day B mở rộng hardening từ "manifest đúng" sang "artifact và secret đáng tin".

## 5. Kết nối với mục tiêu cuối W10

Day B liên quan trực tiếp tới các yêu cầu:

- AWS Secrets Manager + External Secrets Operator.
- Secret rotate dưới 60 giây no-restart.
- Trivy image scan trong CI.
- Cosign signing.
- Admission reject unsigned image.
- Exception policy CVE.

Day B cũng chuẩn bị cho:

- Day C platform integration, vì secret và signed image phải đi vào luồng GitOps end-to-end.
- Lab cleanup, vì secret hardcode và unsigned image là hai rủi ro cần dọn và enforce.
- W11-W12 capstone, vì mini platform cần phát hành workload theo cách có kiểm soát.

Tóm lại, Day B dạy cách tin tưởng đúng thứ: không tin secret trong Git, không tin image chưa scan/ký, và không tin deploy chỉ vì CI từng chạy. Cluster phải tự kiểm tra trước khi cho workload chạy.
