# ATU Request Tracker

Michael Turvey | ATU DevOps | Task 3

A Flask request-tracking API delivered through GitHub Actions to a single-node K3s cluster on AWS EC2. The project demonstrates automated testing, security checks, container publication, cloud deployment, metrics, alerting and centralised logging.

Use sample data only. The application has no authentication and supports creating and listing requests.

## Architecture

GitHub pull requests run quality and container checks. A successful push to main also publishes the tested image to GitHub Container Registry and deploys it to AWS.

GitHub Actions authenticates to AWS through OIDC. Systems Manager Run Command executes the deployment scripts on EC2. Kubernetes deploys the application using the published image digest.

SQLite stores requests on a persistent volume. Prometheus scrapes application metrics. Grafana displays the metrics, and Alloy collects application logs into Loki.

All services use ClusterIP. The EC2 security group has no inbound rules. Browser access uses Systems Manager and Kubernetes port forwarding.

## Repository layout

| Path | Purpose |
| --- | --- |
| app/ | Flask application, templates and instrumentation |
| tests/ | Automated application tests |
| Dockerfile | Container build and non-root runtime |
| compose.yaml | Local container execution |
| .github/workflows/ci.yml | Quality, container and deployment jobs |
| infrastructure/ | Terraform EC2 and security-group configuration |
| k8s/ | Application and monitoring manifests |
| monitoring/ | Metrics, alerts, dashboard and logging configuration |
| scripts/ | K3s bootstrap and deployment scripts |
| evidence/ | Captured execution results and screenshots |
| docs/ | Delivery notes and reflection journal |

## Run locally with Python

Requires Python 3.12 and Git. From the repository directory in Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check .
.\.venv\Scripts\python.exe -m bandit -r app -ll
.\.venv\Scripts\python.exe -m pip_audit -r requirements.txt
.\.venv\Scripts\python.exe -m flask --app app:create_app run
```

Open http://127.0.0.1:5000. The Flask development server is for local development.

In another PowerShell window:

```powershell
$body = @{ title = "Sample ATU request" } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:5000/api/requests -Method Post -ContentType application/json -Body $body
Invoke-RestMethod -Uri http://127.0.0.1:5000/api/requests
```

## Run locally with Docker

Requires Docker Desktop configured for Linux containers.

```powershell
docker compose up --build -d
docker compose ps
docker compose logs app
```

Open http://127.0.0.1:8000.

```powershell
docker compose down
```

The named data volume survives container removal. Adding `-v` deletes the stored demo requests.

## Pipeline behaviour

Pull requests to main and pushes to main run:

1. Ruff linting, Bandit static security analysis, pip-audit dependency checks and pytest.
2. Validation of Prometheus, Loki and Alloy configuration.
3. A container build followed by Trivy scanning. HIGH and CRITICAL findings fail the job, including unfixed findings.
4. An HTTP integration check against the built container, including readiness and API create/list operations.

Successful pushes to main additionally:

1. Publish the tested image to GHCR with the commit SHA as its tag.
2. Retain the registry digest as an artifact.
3. Authenticate to AWS using OIDC.
4. Send the deployment scripts and configuration through Systems Manager.
5. Deploy the image by digest and verify rollout and readiness.
6. Deploy monitoring and verify application scraping and log delivery.

Test reports, coverage, container logs and deployment results are retained as workflow artifacts. Deployment is deliberately skipped on pull requests.

## AWS deployment prerequisites

The current Terraform configuration targets a specific AWS account, Ireland region, VPC, subnet and existing EC2 instance profile. It is not a portable deployment without configuration changes.

Initial setup requires:

- An AWS account with suitable permissions.
- A VPC and subnet with outbound connectivity.
- An EC2 instance profile permitting Systems Manager access.
- A GitHub OIDC provider and deployment role.
- A role trust policy restricted to this repository and main branch.
- Deployment-role permissions for the target EC2 instance and Systems Manager document.
- A publicly readable GHCR image.
- Terraform, AWS CLI and the Session Manager plugin on the operator's computer.

IAM and OIDC were configured separately from Terraform. Changing the target account or recreating the instance also requires reviewing the IAM resource restrictions and workflow instance ID.

From the infrastructure directory, using an authenticated AWS profile:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan -out="deployment.tfplan"
terraform apply "deployment.tfplan"
```

Terraform state is held locally and must be retained securely. State, saved plans and credentials are excluded from Git.

## Access the deployed application and Grafana

Two forwarding processes are required for each service. Keep both running.

In an AWS Session Manager shell, forward the application:

```bash
sudo k3s kubectl port-forward -n tracker service/tracker 8000:80 --address 127.0.0.1
```

In a separate Windows PowerShell window:

```powershell
aws ssm start-session --profile atu-devops --region eu-west-1 --target i-06bb48983057e1c8e --document-name AWS-StartPortForwardingSession --parameters "portNumber=8000,localPortNumber=18000"
```

Open http://localhost:18000.

For Grafana, use a separate AWS shell:

```bash
sudo k3s kubectl port-forward -n tracker service/grafana 3000:3000 --address 127.0.0.1
```

And a separate Windows PowerShell window:

```powershell
aws ssm start-session --profile atu-devops --region eu-west-1 --target i-06bb48983057e1c8e --document-name AWS-StartPortForwardingSession --parameters "portNumber=3000,localPortNumber=13000"
```

Open http://localhost:13000. The username is `admin`. Retrieve the generated password privately in another AWS shell:

```bash
sudo k3s kubectl get secret grafana-admin -n tracker -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Do not include the password in screenshots, recordings or commits.

Closing a tunnel ends browser access without stopping the deployed services. Restart Kubernetes port forwarding if its target pod is replaced.

## Monitoring and logging

The provisioned Grafana dashboard is under **ATU DevOps > ATU Request Tracker**. It displays application reachability, firing application alerts, request rates, status codes and estimated 95th-percentile latency.

In Grafana Explore, select Loki and run:

```logql
{app="tracker"}
```

Prometheus evaluates two application alerts:

- `TrackerUnavailable`: the application metrics endpoint is unavailable for one minute.
- `TrackerHighServerErrorRate`: the measured server-error ratio exceeds 5 percent for two minutes.

Alerts are evaluated in Prometheus and visualised in Grafana. External notification delivery is not configured.

The deployment script checks that Prometheus scrapes the application and that a uniquely identified application request reaches Loki through Alloy. A failed check fails deployment.

Grafana plugin auto-updates are disabled because startup updates attempted to modify bundled plugins on the read-only filesystem. Grafana uses the plugin versions included in its image.

## Verification and evidence

Verified executions include API create/list operations on AWS, successful automated deployment, populated Grafana metrics, centralised application logs, and an outage alert followed by recovery.

See [the evidence index](evidence/README.md) for captured results. The outage exercise used a temporary scale-down followed by automatic restoration. It tested availability alerting, not the high-server-error rule or image rollback.

## Security and operational limits

Application containers run without root privileges, drop capabilities and use read-only root filesystems. Kubernetes resource limits and health probes are configured. EC2 requires IMDSv2 and uses encrypted root storage. GitHub deployment uses temporary OIDC credentials.

This remains a teaching deployment. It has one Kubernetes node and one application replica. Local-path volumes survive pod replacement but do not provide protection against instance or disk loss. There is no automated backup or tested image-rollback procedure.

The API has no user authentication or public HTTPS endpoint. Access is restricted through AWS permissions and local tunnels.

Action references and base-image tags are not all pinned to immutable digests. Published application deployment is pinned by digest.

AWS compute, storage and public IPv4 resources consume account credits or incur charges according to the account plan. Stop EC2 when the demonstration is not needed. Stopping EC2 retains its disk; terminating the current instance deletes its root disk and the local-path data stored there.

## AI assistance

AI assistance supported implementation, troubleshooting and documentation. The submitted behaviour was checked through actual local, GitHub Actions and AWS executions. See AI-USAGE.md for the assistance record.
