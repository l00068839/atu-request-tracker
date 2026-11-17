# Task 4 evidence and reflection journal

Author: Michael Turvey. Student ID and exact module name: confirm before submission.

This is a working journal, not a completed reflection. Record actual experience as it occurs.
The final report must contain 1,000–1,500 words in narrative prose, Harvard citations,
and a code/script appendix. Confirm whether references and appendix are excluded from the
word limit with the lecturer. Do not claim planned features as implemented.

## Initial design decisions — 12 November 2026

A personal GitHub repository and GitHub Actions were selected to keep assessed work
independent of Pinergy's work-owned Azure DevOps. Compare the convenience of integrated
source control and hosted CI against Jenkins maintenance and GitLab's integrated alternative.
Existing Azure DevOps experience is relevant background, but is not evidence of operating
this assignment pipeline.

The Flask application deliberately has a narrow scope so effort can focus on delivery.
SQLite provides real persistence and integration tests with little operational overhead.
It is limited to a single application replica, with no multi-node availability or demonstrated
backup recovery. Evaluate PostgreSQL as a future improvement rather than hiding this limitation.

Metrics use route templates rather than raw URLs to avoid unbounded label cardinality.
A single Gunicorn worker keeps the in-process metrics accurate. Scaling workers would require
Prometheus multiprocess configuration or another instrumentation design.

## Record after EACH meaningful run

### Observed initial security finding — 12 November 2026

During assistant-side local validation, Bandit B108 flagged the default SQLite file path
`/tmp/requests.db` as insecure shared temporary-directory usage. The default was changed
to Flask's application instance directory. Docker uses a dedicated `/data` volume through
the DATABASE environment variable. The finding was resolved in code rather than suppressed.
Re-run results are captured in `evidence/local-validation.txt`. This is assistant-observed
evidence, not a claim that Michael encountered or resolved it independently.

Date and commit SHA:
Goal and expected result:
Actual result and evidence filename / Actions run URL:
Problem and root cause:
Change made and verification:
Alternative considered and why rejected:
Effect on collaboration, automation, measurement or sharing:
Limitation and next improvement:

## Planned evidence, not yet achieved

Successful pull request checks and review history; deliberately failed test on a feature branch;
security gate blocking a controlled unsafe fixture; same scanned image digest deployed;
Terraform plan/apply and teardown; deployment smoke test; Grafana dashboard; searchable logs;
triggered and resolved alert; measured failed-deployment recovery. Redact account and secret data.
Do not bypass security checks simply to get a green build.

## Suggested final word allocation (1,350 words)

Context and aims: 100. Design rationale and alternatives: 250. Challenges and resolutions: 300.
CI/CD benefits and drawbacks: 180. DevOps principles: 250. Prioritised improvements: 170.
Blend discussion across these topics where appropriate and avoid repeating challenges twice.

## Source plan

Verify and read sources before citing them. Include academic research on continuous delivery,
DORA research for empirical industry context, and official GitHub, Docker, AWS, Kubernetes and
Prometheus documentation for specific technical choices. Record author/organisation, year,
title, URL and access date. A successful local run alone does not prove production reliability.
Connect each source to a concrete choice or observation rather than adding decorative citations.

## Appendix plan

Generate the appendix from the final tagged release, with file paths and complete authored
application code, tests, workflows, Docker/Compose files, Terraform, Kubernetes, monitoring and
supporting scripts. Exclude third-party dependencies, secret values, generated state and caches.
Ask the lecturer whether generated lockfiles should be appended or linked from the repository.
