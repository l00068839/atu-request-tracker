# Delivery plan and acceptance criteria

Target the highest rubric bands. Marks depend on the implementation, demonstration and lecturer's judgement.
This package implements the first application/CI stage, not the full Task 3 submission.

| Stage | Acceptance evidence | Status |
|---|---|---|
| Personal repository | Feature branches, meaningful commits, PR checks and release tag | Requires user's GitHub repository |
| App and tests | Persistent API, input validation, unit/integration tests, >=90% branch-aware coverage | Implemented; see local validation evidence |
| CI quality gates | Ruff, Bandit, dependency audit, pytest results | Configured; GitHub run pending |
| Containers | Multi-stage build, non-root user, scan and running-container API test | Configured; Docker execution pending |
| Supply chain | Publish the scanned image, deploy by digest, SHA-pin actions and base images, SBOM/provenance | Planned |
| Infrastructure | Terraform AWS Ireland setup, remote protected state, OIDC trust scoped to repo/environment | Planned, account capabilities must be confirmed |
| Deployment | K3s manifests, persistent volume, probes, limits, automated rollout and smoke test | Planned |
| Observability | Prometheus, Grafana, Loki and log collector, dashboard, firing/resolved alert | Planned |
| Recovery | Deliberate failed rollout, previous image digest restored, timings recorded | Planned |
| Assessment | README, tagged release, live/recorded demo, evidence journal and final reflection | In progress |

## Practical deployment choice

Prefer one personal AWS EC2 host running K3s, with Terraform-managed networking and instance profile.
Do not expose Kubernetes administration or monitoring publicly. Evaluate SSM for remote execution
and session access, avoiding inbound SSH. GitHub OIDC removes a long-lived AWS access key but needs
an initial trust role configured by an authorised administrator. An AWS Academy Learner Lab may
restrict IAM/OIDC, reset sessions, or stop resources, so do not assume it supports this design.
If permissions prevent it, select local Kubernetes with the lecturer's agreement, as permitted by
Task 3, and document the compromise. Check current resource costs before provisioning.

A single host is cost-conscious and reproducible, but is not highly available. Instrumentation can
be resource hungry. Select host size from measured usage. Resource cleanup and budget management
are part of the runbook. Keep demo request data fictional and bind the app locally until remote
access and authentication controls are designed.

## Git history and demonstrations

Create real feature branches and focused PRs as work progresses. Do not fabricate reviewers,
commits, historical problems or retrospective evidence. For an individual project, explain how
PRs provide reviewable changes and how collaboration would work in a team. Record real peer or
lecturer feedback separately if obtained. Choose protected-branch settings available on the account.

The final demo should trace one change through tests, analysis, image scanning, deployment and
health checks, then show metrics, logs and an alert. Show a controlled failure blocking delivery.
Keep the failed run URL and subsequent repair. A green workflow alone is not proof of every stage.
