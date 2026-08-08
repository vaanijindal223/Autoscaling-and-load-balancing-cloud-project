import os
import socket
import time
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

# Simple in-memory counter - resets per instance/container.
# Useful during load testing: if you see the counter and hostname
# both changing across requests, that's your load balancer working.
request_count = 0
start_time = time.time()

# Set this via environment variable in the launch template / task definition
# so responses show which compute platform served the request.
DEPLOYMENT_TARGET = os.environ.get("DEPLOYMENT_TARGET", "unknown")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")


@app.route("/health")
def health():
    """Health check endpoint used by the ALB target group."""
    return jsonify(status="healthy"), 200


@app.route("/")
def index():
    global request_count
    request_count += 1

    uptime_seconds = round(time.time() - start_time, 2)

    return jsonify(
        message="Hello from the Cloud-Native Auto Scaling app!",
        hostname=socket.gethostname(),
        deployment_target=DEPLOYMENT_TARGET,
        app_version=APP_VERSION,
        request_count_on_this_instance=request_count,
        uptime_seconds=uptime_seconds,
        server_time_utc=datetime.now(timezone.utc).isoformat(),
    )


@app.route("/api/info")
def info():
    """Extra endpoint so there's more than one route to demo/test."""
    return jsonify(
        service="autoscaling-demo-app",
        hostname=socket.gethostname(),
        deployment_target=DEPLOYMENT_TARGET,
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
