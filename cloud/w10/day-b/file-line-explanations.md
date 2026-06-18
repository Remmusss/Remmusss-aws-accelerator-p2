# W10 Day B - Giải thích từng dòng/cụm dòng trong file

Tài liệu này giải thích các dòng và thuộc tính đang xuất hiện trong các file Day B. Các dòng/field đã giải thích ở phần chung sẽ không lặp lại ở từng file.

## 1. Dòng chung dùng lại nhiều file

```yaml
apiVersion: ...
kind: ...
metadata:
  name: ...
  namespace: ...
```

Đây là cấu trúc resource Kubernetes. `apiVersion` xác định API group/version, `kind` xác định loại resource, `metadata.name` là tên resource, `metadata.namespace` là namespace chứa resource.

```yaml
labels:
  app.kubernetes.io/name: ...
  app.kubernetes.io/part-of: ...
  owner: ...
  environment: ...
```

Label dùng cho ownership, filtering, policy và evidence.

## 3. `eso/namespace.yaml`

```yaml
kind: Namespace
name: app-dev
environment: dev
```

Tạo namespace app dev để chạy ESO target secret và sample app.

## 4. `eso/serviceaccount.yaml`

```yaml
kind: ServiceAccount
name: eso-reader
namespace: app-dev
```

ServiceAccount cho ESO dùng khi đọc AWS Secrets Manager.

Manifest local/minikube hiện không dùng annotation IRSA trên ServiceAccount này. AWS credential được cấp cho ESO qua Kubernetes Secret `aws-credentials` và `SecretStore.auth.secretRef`.

Nếu chạy trên EKS production-style, có thể thêm annotation IRSA như `eks.amazonaws.com/role-arn`, nhưng đó không phải flow mặc định của lab local này.

## 5. `eso/secretstore.yaml`

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
```

`SecretStore` khai báo backend secret cho một namespace.

```yaml
provider:
  aws:
    service: SecretsManager
```

Chọn AWS Secrets Manager làm backend.

```yaml
region: us-west-2
```

AWS region chứa secret. Day B hiện dùng `us-west-2`, nên mọi lệnh `aws secretsmanager` trong README cũng phải chạy cùng region này.

```yaml
auth:
  secretRef:
    accessKeyIDSecretRef:
      name: aws-credentials
      key: access-key
    secretAccessKeySecretRef:
      name: aws-credentials
      key: secret-access-key
```

ESO đọc AWS access key từ Kubernetes Secret `aws-credentials`. Cách này phù hợp lab local/minikube. Không commit Secret thật vào Git.

## 6. `eso/externalsecret.yaml`

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
```

Resource yêu cầu ESO đồng bộ secret từ backend vào Kubernetes Secret.

```yaml
refreshInterval: 30s
```

ESO kiểm tra secret mới mỗi 30 giây. Chọn 30s để đáp ứng mục tiêu rotate dưới 60 giây.

```yaml
secretStoreRef:
  name: aws-secretsmanager
  kind: SecretStore
```

ExternalSecret dùng SecretStore `aws-secretsmanager`.

```yaml
target:
  name: demo-api-secret
  creationPolicy: Owner
```

Kubernetes Secret được tạo tên `demo-api-secret`. `creationPolicy: Owner` nghĩa là ESO sở hữu Secret này.

```yaml
data:
  - secretKey: username
    remoteRef:
      key: /w10/dev/demo-api
      property: username
```

Map property `username` trong AWS Secrets Manager secret `/w10/dev/demo-api` sang key `username` trong Kubernetes Secret.

Các block `password` và `apiKey` tương tự.

## 7. `eso/sample-app.yaml`

### ConfigMap

```yaml
kind: ConfigMap
name: secret-reader-app
data:
  app.py: |
```

ConfigMap chứa source Python của sample app. Dùng ConfigMap để không phải build image riêng.

```python
import hashlib
import json
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
```

Import thư viện Python dùng để đọc file, hash secret và expose HTTP endpoint.

```python
SECRET_DIR = Path("/var/run/secrets/demo")
```

Đường dẫn mount Kubernetes Secret trong container.

```python
for name in ("username", "password", "apiKey"):
```

Đọc ba key đã sync từ AWS Secrets Manager.

```python
digest = hashlib.sha256(...).hexdigest()
return digest[:16]
```

Trả hash rút gọn thay vì in secret thật ra response/evidence.

```python
HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
```

Chạy HTTP server trong container trên port 8080.

### Deployment

```yaml
kind: Deployment
replicas: 1
```

Chạy một pod sample app.

```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: secret-reader
```

Deployment quản lý pod có label `secret-reader`.

```yaml
template:
```

Pod template mà Deployment sẽ tạo.

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

Pod chạy bằng user non-root ID 1000.

```yaml
image: python:3.12-alpine
command: ["python", "/app/app.py"]
```

Dùng image Python Alpine và chạy app.py từ ConfigMap.

```yaml
ports:
  - name: http
    containerPort: 8080
```

Container expose port 8080 tên `http`.

```yaml
volumeMounts:
  - name: app-code
    mountPath: /app/app.py
    subPath: app.py
```

Mount file `app.py` từ ConfigMap vào container.

```yaml
  - name: app-secret
    mountPath: /var/run/secrets/demo
    readOnly: true
```

Mount Kubernetes Secret vào thư mục app đọc. Dùng volume để secret có thể update mà không restart pod.

```yaml
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
```

Giảm quyền runtime của container.

```yaml
resources:
  requests:
  limits:
```

Đặt request/limit để workload không chạy vô kiểm soát.

```yaml
volumes:
  - name: app-code
    configMap:
      name: secret-reader-app
  - name: app-secret
    secret:
      secretName: demo-api-secret
```

Khai báo source cho hai volume: code từ ConfigMap, secret từ Kubernetes Secret do ESO tạo.

### Service

```yaml
kind: Service
name: secret-reader
```

Expose sample app trong cluster.

```yaml
selector:
  app.kubernetes.io/name: secret-reader
```

Service route traffic tới pod có label này.

```yaml
ports:
  - name: http
    port: 80
    targetPort: http
```

Service nhận port 80 và chuyển tới container port tên `http`.

## 8. `eso/kustomization.yaml` và top-level `kustomization.yaml`

```yaml
kind: Kustomization
resources:
```

Gom nhiều manifest để chạy bằng `kubectl apply -k`.

Day B top-level include `eso` và `signing/verify-policy.yaml`, nhưng khi chạy thật nên thay placeholder trong verify policy trước.

## 9. `signing/verify-policy.yaml`

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
```

Kyverno policy cấp cluster.

```yaml
validationFailureAction: Enforce
```

Violation sẽ bị reject.

```yaml
background: true
```

Kyverno cũng scan resource đã tồn tại.

```yaml
failurePolicy: Fail
```

Nếu webhook lỗi, request bị fail. Chọn strict cho lab security.

```yaml
match:
  any:
    - resources:
        kinds: ["Pod"]
        namespaces: ["app-dev", "app-prod"]
```

Policy áp dụng cho Pod trong namespace app.

```yaml
verifyImages:
```

Kyverno kiểm tra chữ ký image.

```yaml
imageReferences:
  - "ghcr.io/<owner>/*"
```

Chỉ verify image khớp registry pattern này. Placeholder `<owner>` phải thay.

```yaml
mutateDigest: true
verifyDigest: true
required: true
```

Kyverno mutate image sang digest, verify digest và bắt buộc có signature.

```yaml
keyless:
  issuer: https://token.actions.githubusercontent.com
  subject: "https://github.com/<owner>/<repo>/.github/workflows/*"
```

Verify signature keyless từ GitHub Actions OIDC. Placeholder `<owner>/<repo>` phải thay.

## 10. `ci-trivy/github-actions-example.yaml`

```yaml
name: w10-image-security
```

Tên workflow.

```yaml
on:
  pull_request:
  workflow_dispatch:
```

Workflow chạy khi PR đổi file liên quan hoặc chạy thủ công.

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
  security-events: write
```

Quyền GitHub token. `id-token: write` cần cho Cosign keyless signing.

```yaml
env:
  IMAGE: ghcr.io/${{ github.repository_owner }}/w10-demo-api:${{ github.sha }}
```

Image tag theo commit SHA để immutable hơn `latest`.

```yaml
docker build -t "$IMAGE" .
```

Build image.

```yaml
uses: aquasecurity/trivy-action@0.24.0
```

Chạy Trivy trong GitHub Actions, không cần Trivy local.

```yaml
severity: HIGH,CRITICAL
ignore-unfixed: true
exit-code: "1"
```

Fail pipeline nếu có HIGH/CRITICAL đã fixable theo policy lab.

```yaml
docker/login-action@v3
docker push "$IMAGE"
```

Login và push image lên GHCR khi không phải PR.

```yaml
sigstore/cosign-installer@v3
cosign sign --yes "$IMAGE"
```

Cài Cosign trong runner và ký image keyless.

## 11. Markdown evidence/template

Các file trong `evidence/`, `ci-trivy/trivy-policy.md`, `signing/*.md`, `exceptions/cve-exception-template.md` là tài liệu thao tác/evidence, không phải manifest. Chúng dùng để ghi output thật, exception CVE, và lệnh scan/sign/verify.
