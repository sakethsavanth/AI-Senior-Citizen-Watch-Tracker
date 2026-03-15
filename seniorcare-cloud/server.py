"""
ElderHarmony – Local HTTP Server
==================================
Exposes POST /health-data endpoint locally for development and demo.
Wraps the same lambda_handler used in AWS Lambda.

Usage:
    cd seniorcare-cloud
    python server.py
    # → http://localhost:8080/health-data  (POST)
"""

import json
import logging
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

from railtracks_agents.lambda_handler import lambda_handler

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger("elderharmony.server")

HOST = os.getenv("SERVER_HOST", "0.0.0.0")
PORT = int(os.getenv("SERVER_PORT", "8080"))


class HealthHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        if self.path.rstrip("/") != "/health-data":
            self._send(404, {"error": "Not found. Use POST /health-data"})
            return

        content_length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(content_length) if content_length else b""

        try:
            body = raw.decode("utf-8")
            # Validate JSON
            json.loads(body)
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            self._send(400, {"error": f"Invalid JSON: {exc}"})
            return

        # Build API Gateway-style event
        event = {
            "resource": "/health-data",
            "path": "/health-data",
            "httpMethod": "POST",
            "headers": dict(self.headers),
            "body": body,
            "requestContext": {
                "stage": "local",
                "requestId": "local",
                "http": {"method": "POST"},
            },
            "isBase64Encoded": False,
        }

        result = lambda_handler(event, None)
        self._send(result.get("statusCode", 500), json.loads(result.get("body", "{}")))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _send(self, status: int, body: dict):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(body, default=str).encode("utf-8"))


def main():
    server = HTTPServer((HOST, PORT), HealthHandler)
    logger.info("ElderHarmony server running at http://%s:%d/health-data", HOST, PORT)
    print(f"\n  ElderHarmony API Server")
    print(f"  POST http://localhost:{PORT}/health-data")
    print(f"  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped.")
        server.server_close()


if __name__ == "__main__":
    main()
