import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 5,
  duration: "2m",
  thresholds: {
    http_req_failed: ["rate<0.20"],
  },
};

const baseUrl = __ENV.BASE_URL || "http://127.0.0.1:8082";

export default function () {
  const path = Math.random() < 0.35 ? "/error" : "/";
  const response = http.get(`${baseUrl}${path}`);
  check(response, {
    "response received": (r) => r.status >= 200,
  });
  sleep(1);
}
