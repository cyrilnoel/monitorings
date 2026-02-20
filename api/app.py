\
import os
import time
import json
import random
from flask import Flask, request, jsonify
import pymysql
import redis as redis_lib
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# ---- Metrics (Prometheus) ----
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)

LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency in seconds",
    ["method", "endpoint"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.2, 0.35, 0.5, 0.75, 1, 2, 3, 5),
)

# ---- Env ----
MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_DB = os.getenv("MYSQL_DB", "medassist")
MYSQL_USER = os.getenv("MYSQL_USER", "medassist")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "medassistpass")

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

# ---- Helpers ----
def mysql_ok() -> bool:
    try:
        conn = pymysql.connect(
            host=MYSQL_HOST,
            port=MYSQL_PORT,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD,
            database=MYSQL_DB,
            connect_timeout=2,
            read_timeout=2,
            write_timeout=2,
        )
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
        conn.close()
        return True
    except Exception:
        return False

def redis_ok() -> bool:
    try:
        r = redis_lib.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=2, socket_timeout=2)
        return r.ping() is True
    except Exception:
        return False

def log_json(method: str, endpoint: str, status: int, duration_s: float):
    # Logs JSON structurés (Filebeat/Kibana)
    payload = {
        "ts": int(time.time()),
        "method": method,
        "endpoint": endpoint,
        "status": status,
        "duration": round(duration_s, 6),
        "remote_addr": request.headers.get("X-Real-IP", request.remote_addr),
        "user_agent": request.headers.get("User-Agent", ""),
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)

@app.before_request
def _start_timer():
    request._start_time = time.time()

@app.after_request
def _after(resp):
    try:
        duration = time.time() - getattr(request, "_start_time", time.time())
        endpoint = request.path
        method = request.method
        status = resp.status_code

        REQUESTS.labels(method=method, endpoint=endpoint, status=str(status)).inc()
        LATENCY.labels(method=method, endpoint=endpoint).observe(duration)

        log_json(method, endpoint, status, duration)
    except Exception:
        pass
    return resp

# ---- Endpoints ----
@app.get("/health")
def health():
    m_ok = mysql_ok()
    r_ok = redis_ok()
    ok = m_ok and r_ok
    return jsonify({"ok": ok, "mysql": m_ok, "redis": r_ok}), (200 if ok else 503)

@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

@app.get("/api/doctors")
def doctors():
    data = [
        {"id": 1, "name": "Dr. Martin", "speciality": "Généraliste"},
        {"id": 2, "name": "Dr. Dubois", "speciality": "Dermatologie"},
        {"id": 3, "name": "Dr. Nguyen", "speciality": "Pédiatrie"},
    ]
    return jsonify(data)

@app.route("/api/consultations", methods=["GET", "POST"])
def consultations():
    if request.method == "POST":
        # Simule une création (sans dépendre du schéma MySQL)
        body = request.get_json(silent=True) or {}
        return jsonify({"created": True, "id": random.randint(1000, 9999), "payload": body}), 201
    # GET
    return jsonify([{"id": 101, "patient": "Alice", "doctor": "Dr. Martin", "status": "scheduled"}])

@app.route("/api/payment", methods=["GET", "POST"])
def payment():
    # ~5% erreurs simulées
    if random.random() < 0.05:
        return jsonify({"ok": False, "error": "payment_processing_failed"}), 500
    return jsonify({"ok": True, "transaction_id": f"tx_{random.randint(100000, 999999)}"})

@app.post("/api/webhook/alert")
def webhook_alert():
    body = request.get_json(silent=True)
    # Juste loguer pour montrer le routage Alertmanager
    print(json.dumps({"alert_webhook_received": True, "payload": body}, ensure_ascii=False), flush=True)
    return jsonify({"received": True}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
