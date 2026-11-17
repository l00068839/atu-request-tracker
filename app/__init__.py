"""Small, observable request tracker for the ATU pipeline assignment."""
import json
import logging
import os
import sqlite3
import time
from pathlib import Path

from flask import Flask, g, jsonify, render_template, request
from prometheus_client import CollectorRegistry, Counter, Histogram, generate_latest


def create_app(config=None):
    app = Flask(__name__)
    app.config.update(DATABASE=os.environ.get("DATABASE", str(Path(app.instance_path) / "requests.db")),
                      MAX_CONTENT_LENGTH=16384)
    if config:
        app.config.update(config)
    Path(app.config["DATABASE"]).parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(app.config["DATABASE"]) as db:
        db.execute("CREATE TABLE IF NOT EXISTS requests "
                   "(id INTEGER PRIMARY KEY, title TEXT NOT NULL)")
    registry = CollectorRegistry()
    count = Counter("tracker_http_requests_total", "Completed requests",
                    ["method", "route", "status"], registry=registry)
    duration = Histogram("tracker_http_request_duration_seconds", "Request latency",
                         ["route"], registry=registry)

    @app.before_request
    def start_timer():
        g.started = time.perf_counter()

    @app.after_request
    def observe(response):
        route = request.url_rule.rule if request.url_rule else "unmatched"
        elapsed = time.perf_counter() - g.started
        if route != "/metrics":
            count.labels(request.method, route, str(response.status_code)).inc()
            duration.labels(route).observe(elapsed)
        app.logger.info(json.dumps({"event": "http_request", "method": request.method,
                                    "route": route, "status": response.status_code,
                                    "duration_ms": round(elapsed * 1000, 3)}))
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'unsafe-inline'"
        return response

    @app.get("/")
    def index():
        return render_template("index.html")

    @app.get("/healthz")
    def health():
        return jsonify(status="ok")

    @app.get("/readyz")
    def ready():
        try:
            with sqlite3.connect(app.config["DATABASE"]) as db:
                db.execute("SELECT 1 FROM requests LIMIT 1")
        except sqlite3.Error:
            return jsonify(status="unavailable"), 503
        return jsonify(status="ready")

    @app.get("/metrics")
    def metrics():
        return app.response_class(generate_latest(registry),
                                  content_type="text/plain; version=0.0.4; charset=utf-8")

    @app.route("/api/requests", methods=["GET", "POST"])
    def requests_api():
        if request.method == "POST":
            data = request.get_json(silent=True)
            title = data.get("title") if isinstance(data, dict) else None
            if not isinstance(title, str) or not 1 <= len(title.strip()) <= 120:
                return jsonify(error="Title must contain 1 to 120 characters."), 400
            with sqlite3.connect(app.config["DATABASE"]) as db:
                cursor = db.execute("INSERT INTO requests(title) VALUES (?)", (title.strip(),))
                request_id = cursor.lastrowid
            return jsonify(id=request_id, title=title.strip(), status="Open"), 201
        with sqlite3.connect(app.config["DATABASE"]) as db:
            rows = db.execute("SELECT id, title FROM requests ORDER BY id DESC").fetchall()
        return jsonify([{"id": row[0], "title": row[1], "status": "Open"} for row in rows])

    app.logger.setLevel(logging.INFO)
    return app
