# ATU Request Tracker

Michael Turvey · DevOps ATU · Task 3 practical pipeline and Task 4 reflection evidence.
Confirm the exact module name and student ID before assessed documents are produced.

## Current scope

First-stage starter: Flask API, persisted sample requests, tests, structured request logs,
Prometheus endpoint, quality checks, Docker build and CI configuration.
Cloud deployment, image publication, Grafana/Loki, alerting and rollback are NOT yet implemented.
See `docs/delivery-plan.md` for the remaining acceptance criteria.

## Run on Windows PowerShell

Requires Python 3.12 and Git. Extract into `C:\devops-atu\atu-request-tracker`.

```powershell
cd C:\devops-atu\atu-request-tracker
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check .
.\.venv\Scripts\python.exe -m bandit -r app -ll
.\.venv\Scripts\python.exe -m pip_audit -r requirements.txt
.\.venv\Scripts\python.exe -m flask --app app:create_app run
```

Visit http://127.0.0.1:5000. The Flask server is for local development only.
Example sample request in another PowerShell terminal:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:5000/api/requests -Method Post -ContentType 'application/json' -Body '{"title":"Sample customer request"}'
Invoke-RestMethod -Uri http://127.0.0.1:5000/api/requests
```

With Docker Desktop configured for Linux containers:

```powershell
docker compose up --build -d
docker compose ps
docker compose logs app
docker compose down
```

Docker serves http://127.0.0.1:8000. Its named volume survives `down`.
`docker compose down -v` deletes demo request data. Do this only when intentionally resetting it.

## Tests and instrumentation

Tests cover validation, length boundaries, malformed/oversized requests, parameterised SQL,
real SQLite persistence across app instances, health/readiness distinction and metric labels.
These are application/database integration tests. The configured CI container job separately
checks HTTP requests against Gunicorn in the built image. Coverage is not a substitute for
user-facing end-to-end tests or operational recovery tests, which will be added later.

`/healthz` checks the process. `/readyz` checks that the database table can be read.
`/metrics` exposes bounded-label counters and latency histograms. Request logs contain method,
route template, status and latency, not submitted titles. There is no authentication yet.
The API intentionally supports create/list only, with each request initially Open.

## CI gates

Pull requests and main pushes run Ruff, Bandit, pip-audit and pytest. The downstream job builds
a non-root image, blocks HIGH/CRITICAL Trivy findings (including unfixed findings), and runs an
HTTP integration check. No cloud credentials or deployment permissions are included at this stage.
Current action references use release tags. Pin full action SHAs and base-image digests as part
of supply-chain hardening before the final assessed release. Dependency versions are captured
for reproducibility, but hash locking and repeatable clean rebuilds still need assessment.

## Evidence and reflection

Local verification output is in `evidence/local-validation.txt`. GitHub, Docker and AWS results
must be captured from actual executions. Update `docs/task4-journal.md` after meaningful runs.
Record AI assistance according to the module's policy and be prepared to explain all submitted code.
Do not upload passwords, tokens, Terraform state, personal request data or unredacted cloud secrets.
