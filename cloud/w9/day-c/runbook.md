# Day C Runbook - Canary Auto-Abort

## 1. Điều kiện trước khi chạy

Day A và Day B cần đang hoạt động:

```powershell
kubectl get applications -n argocd
kubectl get pods -n observability
kubectl get prometheusrule,servicemonitor -n observability
```

Cần cài Argo Rollouts CRD/controller trước khi apply Day C:

```powershell
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl get pods -n argo-rollouts
```

Runbook này dùng `kubectl` thuần để không phụ thuộc plugin `kubectl argo rollouts`.

## 2. Build image demo vào minikube

```powershell
minikube image build -t demo-web-metrics:v1 cloud/w9/day-b/demo-app
minikube image build -t demo-web-metrics:v2 cloud/w9/day-b/demo-app
```

## 3. Apply Day C

```powershell
kubectl apply -k cloud/w9/day-c
kubectl get rollout,analysisrun,rs,pods -n lab
kubectl describe rollout demo-web-rollout -n lab
```

Theo dõi liên tục bằng:

```powershell
kubectl get rollout,analysisrun,rs,pods -n lab --watch
```

## 4. Mở app canary

Terminal 1:

```powershell
kubectl port-forward -n lab svc/demo-web-rollout 8082:80
```

Terminal 2:

```powershell
curl http://127.0.0.1:8082/
curl http://127.0.0.1:8082/metrics
```

## 5. Kiểm tra Prometheus đã scrape app canary

Trong Prometheus UI:

```promql
sum(rate(demo_web_http_requests_total{app="demo-web-rollout"}[2m]))
```

```promql
histogram_quantile(0.95, sum by (le) (rate(demo_web_http_request_duration_seconds_bucket{app="demo-web-rollout"}[2m])))
```

## 6. Demo promote thành công

Tạo traffic tốt:

```powershell
k6 run cloud/w9/day-c/load-tests/k6-canary-good.js
```

Kích hoạt rollout sang image `v2`:

```powershell
kubectl patch rollouts.argoproj.io demo-web-rollout -n lab --type=merge --patch-file cloud/w9/day-c/patches/image-v2-merge.json
kubectl get rollout,analysisrun,rs,pods -n lab --watch
```

Kỳ vọng:

- rollout lên 20%
- chạy analysis
- lên 50%
- chạy analysis
- promote 100%

## 7. Demo auto-abort

Rollback về version ổn định trước:

```powershell
kubectl patch rollouts.argoproj.io demo-web-rollout -n lab --type=merge --patch-file cloud/w9/day-c/patches/image-v1-merge.json
kubectl get rollout,analysisrun,rs,pods -n lab --watch
```

Tạo rollout mới:

```powershell
kubectl patch rollouts.argoproj.io demo-web-rollout -n lab --type=merge --patch-file cloud/w9/day-c/patches/image-v2-merge.json
```

Trong lúc rollout đang analysis, chạy traffic xấu:

```powershell
k6 run cloud/w9/day-c/load-tests/k6-canary-bad.js
```

Nếu chưa cài k6, có thể tạo traffic lỗi bằng PowerShell:

```powershell
kubectl port-forward -n lab svc/demo-web-rollout 8082:80
```

Terminal khác:

```powershell
1..180 | ForEach-Object { try { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8082/error | Out-Null } catch {}; Start-Sleep -Milliseconds 300 }
```

Kỳ vọng:

- metric error rate vượt 5%
- `AnalysisRun` fail
- rollout abort

Kiểm tra:

```powershell
kubectl get analysisrun -n lab
kubectl describe rollout demo-web-rollout -n lab
```

## 8. Lệnh hữu ích

```powershell
kubectl get rollout,analysisrun,rs,pods -n lab
kubectl describe rollout demo-web-rollout -n lab
kubectl describe analysisrun -n lab
```
