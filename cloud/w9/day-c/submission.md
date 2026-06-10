# Day C Submission

## Những gì đã nộp

- `cloud/w9/day-c/rollout/demo-web-rollout.yaml`: Rollout canary cho app `demo-web-rollout`.
- `cloud/w9/day-c/rollout/demo-web-service.yaml`: Service expose app canary qua NodePort `32124`.
- `cloud/w9/day-c/rollout/demo-web-servicemonitor.yaml`: ServiceMonitor để Prometheus scrape `/metrics`.
- `cloud/w9/day-c/analysis-template/demo-web-prometheus-analysis.yaml`: AnalysisTemplate dùng Prometheus kiểm tra error rate và p95 latency.
- `cloud/w9/day-c/load-tests/k6-canary-good.js`: k6 traffic tốt để rollout promote.
- `cloud/w9/day-c/load-tests/k6-canary-bad.js`: k6 traffic lỗi để chứng minh rollout abort.
- `cloud/w9/day-c/patches/image-v1-merge.json`: patch quay về image `v1`.
- `cloud/w9/day-c/patches/image-v2-merge.json`: patch kích hoạt rollout sang image `v2`.
- `cloud/w9/day-c/runbook.md`: hướng dẫn chạy từng bước.

## Ý nghĩa

Day C nối trực tiếp vào nền Day B:

`Rollout -> AnalysisTemplate -> Prometheus query -> auto promote hoặc abort`

## Tiêu chí đạt

- Có `Rollout` thay cho `Deployment`.
- Có canary steps `20% -> analysis -> 50% -> analysis -> 100%`.
- Có `AnalysisTemplate` dùng Prometheus.
- Có tiêu chí abort theo error rate và p95 latency.
- Có script tạo traffic để kiểm chứng metric.
