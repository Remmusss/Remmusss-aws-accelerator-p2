from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import time


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/readyz"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return

        body = json.dumps(
            {
                "service": "fe-be-backend",
                "message": "Hello from backend",
                "pod": os.environ.get("HOSTNAME", "unknown"),
                "unix_time": int(time.time()),
            }
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
