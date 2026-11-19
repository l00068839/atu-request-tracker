#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECTL=(k3s kubectl)

"${KUBECTL[@]}" get namespace tracker >/dev/null

# Generate the initial password on the server, without printing it.
if ! "${KUBECTL[@]}" get secret grafana-admin -n tracker >/dev/null 2>&1; then
  PASSWORD_FILE="$(mktemp)"
  chmod 600 "${PASSWORD_FILE}"
  trap 'rm -f "${PASSWORD_FILE}"' EXIT

  python3 -c 'import secrets; print(secrets.token_urlsafe(32), end="")' \
    > "${PASSWORD_FILE}"

  "${KUBECTL[@]}" create secret generic grafana-admin -n tracker \
    --from-file=admin-password="${PASSWORD_FILE}"

  rm -f "${PASSWORD_FILE}"
fi

"${KUBECTL[@]}" create configmap prometheus-config -n tracker \
  --from-file=prometheus.yml="${PROJECT_DIR}/monitoring/prometheus.yml" \
  --from-file=alerts.yml="${PROJECT_DIR}/monitoring/alerts.yml" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" create configmap grafana-datasources -n tracker \
  --from-file=datasources.yml="${PROJECT_DIR}/monitoring/grafana-datasources.yml" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" create configmap grafana-providers -n tracker \
  --from-file=dashboards.yml="${PROJECT_DIR}/monitoring/grafana-dashboards.yml" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" create configmap grafana-dashboard -n tracker \
  --from-file=tracker.json="${PROJECT_DIR}/monitoring/tracker-dashboard.json" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" create configmap loki-config -n tracker \
  --from-file=loki.yml="${PROJECT_DIR}/monitoring/loki.yml" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" create configmap alloy-config -n tracker \
  --from-file=config.alloy="${PROJECT_DIR}/monitoring/config.alloy" \
  --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f -

"${KUBECTL[@]}" apply -f "${PROJECT_DIR}/k8s/loki.yaml"
"${KUBECTL[@]}" apply -f "${PROJECT_DIR}/k8s/alloy.yaml"

"${KUBECTL[@]}" apply -f "${PROJECT_DIR}/k8s/prometheus.yaml"
"${KUBECTL[@]}" apply -f "${PROJECT_DIR}/k8s/grafana.yaml"

# Restart monitoring pods when their configuration changes.
CONFIG_HASH="$(cat "${PROJECT_DIR}"/monitoring/* | sha256sum | cut -d ' ' -f 1)"

for deployment in loki alloy prometheus grafana; do
  "${KUBECTL[@]}" patch deployment "${deployment}" -n tracker \
    --type=merge \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"atu/config-hash\":\"${CONFIG_HASH}\"}}}}}"

  "${KUBECTL[@]}" rollout status deployment/"${deployment}" \
    -n tracker --timeout=180s
done

"${KUBECTL[@]}" exec -n tracker deployment/prometheus -- \
  promtool check config /etc/prometheus/prometheus.yml

# Fail deployment if Prometheus cannot collect application metrics.
"${KUBECTL[@]}" exec -i -n tracker deployment/tracker -- python - <<'PY'
import json
import time
import urllib.parse
import urllib.request

query = urllib.parse.urlencode({"query": 'up{job="tracker"}'})
url = "http://prometheus:9090/api/v1/query?" + query

for attempt in range(30):
    with urllib.request.urlopen(url, timeout=10) as response:
        payload = json.load(response)
    results = payload.get("data", {}).get("result", [])
    if payload.get("status") == "success" and results:
        if all(float(row["value"][1]) == 1 for row in results):
            print("Monitoring check passed: Prometheus is scraping Request Tracker.")
            break
    time.sleep(2)
else:
    raise SystemExit("Monitoring check failed: tracker scrape is not healthy.")
PY

"${KUBECTL[@]}" get pods,pvc,svc -n tracker

# Generate a unique access-log entry and verify delivery through Alloy to Loki.
"${KUBECTL[@]}" exec -i -n tracker deployment/tracker -- python - <<'PY'
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

marker = "atu-observability-" + uuid.uuid4().hex
started = time.time_ns() - 60_000_000_000

with urllib.request.urlopen(
    "http://127.0.0.1:8000/healthz?monitoring_check=" + marker,
    timeout=10,
) as response:
    assert response.status == 200

query = '{app="tracker"} |= "' + marker + '"'

for attempt in range(45):
    parameters = urllib.parse.urlencode({
        "query": query,
        "start": str(started),
        "end": str(time.time_ns()),
        "limit": "20",
    })
    url = "http://loki:3100/loki/api/v1/query_range?" + parameters
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            payload = json.load(response)
        results = payload.get("data", {}).get("result", [])
        found = any(
            marker in entry[1]
            for stream in results
            for entry in stream.get("values", [])
        )
        if payload.get("status") == "success" and found:
            print("Logging check passed: application -> Alloy -> Loki.")
            break
    except (urllib.error.URLError, TimeoutError) as error:
        print("Waiting for Loki:", type(error).__name__)
    time.sleep(2)
else:
    raise SystemExit("Logging check failed: the application log did not reach Loki.")
PY
