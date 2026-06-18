# W10 Day B - Cách chạy

## 1. Mục tiêu

Chạy phần Secrets Rotation và Supply Chain Security:

- Tạo AWS Secrets Manager secret.
- Apply ESO `SecretStore` và `ExternalSecret`.
- Chạy sample app đọc secret qua mounted volume.
- Kiểm tra rotate secret dưới 60 giây, không restart pod.
- Dùng Trivy scan image.
- Dùng Cosign ký và verify image.
- Dùng Kyverno policy reject unsigned image.

## 2. Kiểm tra tool

Chạy:

```powershell
aws sts get-caller-identity
kubectl get nodes
helm version
trivy --version
cosign version
```

Nếu gặp lỗi:

```text
trivy : The term 'trivy' is not recognized
cosign : The term 'cosign' is not recognized
```

thì máy chưa cài Trivy/Cosign hoặc chưa thêm vào `PATH`.

## 3. Cài Trivy và Cosign trên Windows

### Cách A: dùng winget

Tìm package:

```powershell
winget search trivy
winget search cosign
```

Cài theo ID hiển thị từ `winget search`. Thường sẽ là:

```powershell
winget install --id AquaSecurity.Trivy -e
winget install --id Sigstore.Cosign -e
```

Đóng terminal, mở PowerShell mới rồi kiểm tra lại:

```powershell
trivy --version
cosign version
```

Nếu `winget install --id Sigstore.Cosign -e --scope user` báo đã cài nhưng `cosign version` vẫn báo `The term 'cosign' is not recognized`, kiểm tra WinGet Links:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -Filter cosign.exe -ErrorAction SilentlyContinue
```

Nếu thấy `cosign.exe`, thêm thư mục Links vào User `PATH`:

```powershell
$links = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $links) {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$links", "User")
}
```

Đóng PowerShell, mở PowerShell mới rồi kiểm tra:

```powershell
where.exe cosign
cosign version
```

Nếu thư mục Links không có `cosign.exe`, tìm trong package directory:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter cosign.exe -ErrorAction SilentlyContinue | Select-Object FullName
```

Nếu tìm thấy file, thêm thư mục chứa `cosign.exe` vào User `PATH`.

### Cách B: dùng Scoop

Nếu máy có Scoop:

```powershell
scoop install trivy cosign
```

Kiểm tra lại:

```powershell
trivy --version
cosign version
```

### Cách C: không cài local, chạy bằng GitHub Actions

Nếu chỉ cần hoàn thành phần CI evidence, có thể dùng workflow mẫu:

```text
cloud/w10/day-b/ci-trivy/github-actions-example.yaml
```

Workflow này dùng `aquasecurity/trivy-action` để scan và `sigstore/cosign-installer` để cài Cosign trong GitHub Actions runner. Khi dùng cách này, máy local không cần có `trivy` và `cosign`, nhưng phần evidence local sẽ thay bằng GitHub Actions log.

## 4. Chuẩn bị AWS auth cho ESO

Manifest hiện tại dùng mode local/minikube: `SecretStore` đọc AWS credential từ Kubernetes Secret tên `aws-credentials` trong namespace `app-dev`.

Tạo Secret này từ AWS profile local:

```powershell
$ak = aws configure get aws_access_key_id
$sk = aws configure get aws_secret_access_key
kubectl -n app-dev create secret generic aws-credentials `
  --from-literal=access-key=$ak `
  --from-literal=secret-access-key=$sk `
  --dry-run=client -o yaml | kubectl apply -f -
```

Không commit credential thật vào Git.

Nếu chạy trên EKS production-style, có thể đổi `SecretStore` về IRSA bằng cách dùng annotation trong:

```text
cloud/w10/day-b/eso/serviceaccount.yaml
```

Thay:

```text
arn:aws:iam::<account-id>:role/w10-eso-reader
```

bằng IAM role thật có quyền đọc `/w10/dev/*` trong AWS Secrets Manager.

## 5. Tạo secret trong AWS Secrets Manager

Tạo secret:

```powershell
aws secretsmanager create-secret `
  --region us-west-2 `
  --name /w10/dev/demo-api `
  --secret-string '{"username":"demo","password":"initial-password","apiKey":"initial-key"}'
```

Nếu secret đã tồn tại:

```powershell
aws secretsmanager put-secret-value `
  --region us-west-2 `
  --secret-id /w10/dev/demo-api `
  --secret-string '{"username":"demo","password":"initial-password","apiKey":"initial-key"}'
```

Không đưa secret thật vào evidence.

## 6. Cài External Secrets Operator

```powershell
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets `
  --namespace external-secrets `
  --create-namespace `
  --set installCRDs=true
```

Kiểm tra:

```powershell
kubectl -n external-secrets get pods
kubectl get crd | Select-String external-secrets
```

## 7. Apply ESO và sample app

```powershell
kubectl apply -k cloud/w10/day-b/eso
```

Kiểm tra:

```powershell
kubectl -n app-dev get externalsecret demo-api-secret
kubectl -n app-dev describe externalsecret demo-api-secret
kubectl -n app-dev get secret demo-api-secret
kubectl -n app-dev get deploy,svc,pod -l app.kubernetes.io/name=secret-reader
```

## 8. Test secret rotation

Port-forward sample app:

```powershell
kubectl -n app-dev port-forward svc/secret-reader 18080:80
```

Ở terminal khác:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:18080 | Select-Object -ExpandProperty Content
```

Rotate secret:

```powershell
aws secretsmanager put-secret-value `
  --region us-west-2 `
  --secret-id /w10/dev/demo-api `
  --secret-string '{"username":"demo","password":"rotated-password","apiKey":"rotated-key"}'
```

Gọi lại endpoint trong dưới 60 giây:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:18080 | Select-Object -ExpandProperty Content
```

Kết quả mong muốn:

- `secretHash` thay đổi.
- Pod restart count không tăng.

Ghi kết quả vào:

```text
cloud/w10/day-b/evidence/eso-rotation.md
```

## 9. Trivy scan

Yêu cầu: `trivy --version` phải chạy được nếu scan local.

Scan image:

```powershell
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ghcr.io/<owner>/<image>:<git-sha>
```

Lệnh này chỉ chạy được khi image pull được:

- Nếu image đã có trong local Docker, Trivy sẽ scan từ local daemon.
- Nếu image ở GHCR và package là private, cần đăng nhập trước:

```powershell
docker login ghcr.io
```

Nếu lỗi:

```text
DENIED: requested access to the resource is denied
```

thì nguyên nhân thường là:

- package private nhưng chưa login,
- tag không tồn tại,
- sai `<owner>` hoặc `<image>`.

Ghi kết quả vào:

```text
cloud/w10/day-b/evidence/trivy-scan.md
```

Nếu không cài Trivy local, dùng GitHub Actions workflow mẫu và copy summary/log vào evidence.

## 10. Cosign sign và verify

Yêu cầu: `cosign version` phải chạy được nếu ký local.

Keyless:

```powershell
cosign sign --yes ghcr.io/<owner>/<image>:<git-sha>
cosign verify `
  --certificate-identity-regexp "https://github.com/<owner>/<repo>/.github/workflows/.*" `
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" `
  ghcr.io/<owner>/<image>:<git-sha>
```

Flow này dành cho GitHub Actions OIDC. Không nên coi đây là lệnh local mặc định vì máy local không có GitHub OIDC identity để ký keyless theo mẫu trên.

Key-based:

Nếu làm local theo flow đẩy image lên GHCR rồi mới ký, chạy theo thứ tự này:

```powershell
# ví dụ dùng app có Dockerfile ở cloud/w9/day-b/demo-app
Set-Location cloud/w9/day-b/demo-app

$OWNER = "remmusss"
$TAG = "w10-demo-api:manual-001"
$IMAGE = "ghcr.io/$OWNER/$TAG"

docker build -t w10-demo-api:local .
docker tag w10-demo-api:local $IMAGE
docker login ghcr.io
docker push $IMAGE
```

Sau khi image đã tồn tại trên GHCR mới tạo key, ký và verify:

```powershell
cosign generate-key-pair
cosign sign --key cosign.key ghcr.io/<owner>/<image>:<git-sha>
cosign verify --key cosign.pub ghcr.io/<owner>/<image>:<git-sha>
```

Không commit `cosign.key`.

Ghi kết quả vào:

```text
cloud/w10/day-b/evidence/cosign-sign-verify.md
```

Nếu không cài Cosign local, dùng GitHub Actions workflow mẫu để cài Cosign trong runner và lấy log làm evidence.

## 11. Apply image verification policy

Trước khi apply, thay placeholder trong:

```text
cloud/w10/day-b/signing/verify-policy.yaml
```

Các placeholder:

- `<owner>`
- `<repo>`
- Registry image pattern `ghcr.io/<owner>/*`

Apply:

```powershell
kubectl apply -f cloud/w10/day-b/signing/verify-policy.yaml
```

Test unsigned/signed image theo:

```text
cloud/w10/day-b/evidence/admission-reject.md
```
