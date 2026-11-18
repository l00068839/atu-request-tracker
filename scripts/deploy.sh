#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Provide the container image digest}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "${IMAGE}" =~ ^ghcr\.io/l00068839/atu-request-tracker@sha256:[a-f0-9]{64}$ ]]; then
  echo "Expected an immutable image digest from the project GHCR package."
  exit 1
fi

bash "${PROJECT_DIR}/scripts/bootstrap-k3s.sh"

MANIFEST="$(mktemp)"
trap 'rm -f "${MANIFEST}"' EXIT

python3 - "${PROJECT_DIR}/k8s/tracker.yaml" "${MANIFEST}" "${IMAGE}" <<'PY'
import pathlib
import re
import sys

source, destination, image = sys.argv[1:]
manifest = pathlib.Path(source).read_text(encoding="utf-8-sig")
manifest, replacements = re.subn(
    r"(?m)^(\s*image:\s*).+$",
    lambda match: match.group(1) + image,
    manifest,
)
if replacements != 1:
    raise SystemExit("Expected exactly one application image in the manifest.")
pathlib.Path(destination).write_text(manifest, encoding="utf-8")
PY

k3s kubectl apply -f "${MANIFEST}"
k3s kubectl rollout status deployment/tracker -n tracker --timeout=180s

k3s kubectl exec -n tracker deployment/tracker -- python -c \
  'import json,urllib.request; result=json.load(urllib.request.urlopen("http://127.0.0.1:8000/readyz", timeout=10)); assert result["status"] == "ready"; print("Deployment readiness check passed")'

k3s kubectl get pods,pvc,svc -n tracker
echo "Deployed image: ${IMAGE}"
