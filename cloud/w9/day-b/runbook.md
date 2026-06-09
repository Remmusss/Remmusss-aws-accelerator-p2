# Day B Demo Runbook

## 1. Build image vào minikube

```powershell
minikube image build -t demo-web-metrics:local cloud/w9/day-b/demo-app
```

## 2. Redeploy app demo-web

Nếu bạn đang dùng Argo CD cho Day A, chỉ cần commit và push rồi để Argo CD sync.

Nếu đang demo trực tiếp bằng kubectl:

```powershell
kubectl apply -k cloud/w9/day-a/manifests/demo-web/overlays/minikube
kubectl rollout status deployment/demo-web -n lab
```

## 3. Apply observability bundle

```powershell
kubectl apply -k cloud/w9/day-b
```

## 4. Kiểm tra ServiceMonitor và metrics endpoint

```powershell
kubectl get servicemonitor -n observability
kubectl get svc demo-web -n lab
kubectl port-forward -n lab svc/demo-web 8080:80
```

Ở terminal khác:

```powershell
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/metrics
curl http://127.0.0.1:8080/slow
curl http://127.0.0.1:8080/error
```

## 5. Tạo traffic có kiểm soát

```powershell
1..100 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/ | Out-Null }
1..30 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/slow | Out-Null }
1..20 | ForEach-Object { try { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8080/error | Out-Null } catch {} }
```

## 6. Kiểm tra Prometheus query

```promql
sum(rate(demo_web_http_requests_total{app="demo-web"}[5m]))
```

```promql
sum(rate(demo_web_http_requests_total{app="demo-web",status_code=~"5.."}[5m]))
/
sum(rate(demo_web_http_requests_total{app="demo-web"}[5m]))
```

```promql
histogram_quantile(0.95, sum by (le) (rate(demo_web_http_request_duration_seconds_bucket{app="demo-web"}[5m])))
```

## 7. Grafana dashboard

Import:

- `cloud/w9/day-b/dashboards/demo-web-observability.json`

## 8. Lưu ý

- `ServiceMonitor` hiện gắn label `release: kube-prometheus-stack`. Nếu Helm release Prometheus của bạn không tên này, đổi label cho khớp selector của Prometheus Operator.
