import os
import time
from flask import Flask, Response, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest


app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "demo-web")
APP_VERSION = os.getenv("APP_VERSION", "v1")

REQUEST_COUNT = Counter(
    "demo_web_http_requests_total",
    "Total HTTP requests handled by demo-web.",
    ["app", "method", "endpoint", "status_code"],
)

REQUEST_DURATION = Histogram(
    "demo_web_http_request_duration_seconds",
    "HTTP request latency for demo-web.",
    ["app", "method", "endpoint", "status_code"],
    buckets=(0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5),
)


@app.before_request
def before_request() -> None:
    request.start_time = time.perf_counter()


@app.after_request
def after_request(response):
    elapsed = time.perf_counter() - getattr(request, "start_time", time.perf_counter())
    endpoint = request.path
    status_code = str(response.status_code)
    REQUEST_COUNT.labels(APP_NAME, request.method, endpoint, status_code).inc()
    REQUEST_DURATION.labels(APP_NAME, request.method, endpoint, status_code).observe(elapsed)
    return response


@app.get("/")
def home():
    return jsonify(
        {
            "app": APP_NAME,
            "version": APP_VERSION,
            "message": "demo-web is running",
            "hint": "Try /slow, /error and /metrics for observability demo",
        }
    )


@app.get("/slow")
def slow():
    time.sleep(0.75)
    return jsonify({"app": APP_NAME, "status": "slow endpoint completed"})


@app.get("/error")
def error():
    return jsonify({"app": APP_NAME, "status": "intentional error"}), 500


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
