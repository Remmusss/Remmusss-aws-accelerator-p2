# Loki / LogQL Queries

## Các query nên demo

```logql
{namespace="lab", app="demo-web"}
```

```logql
{namespace="lab", app="demo-web"} |= "error"
```

```logql
count_over_time({namespace="lab", app="demo-web"}[5m])
```

## Mục đích

- Xem log của app theo namespace và label.
- Liên hệ thời điểm spike lỗi với alert hoặc rollout.
- Chuẩn bị cho Day C khi cần kiểm tra canary bị abort vì metric nào và log nào.
