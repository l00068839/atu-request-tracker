# Task 3 evidence index

Evidence was captured from local checks, GitHub Actions and the AWS deployment. Screenshots record particular executions rather than the current live state.

## Local verification

| File | Evidence |
| --- | --- |
| local-validation.txt | Initial assistant-executed lint, static analysis, dependency audit and application tests |
| http-smoke.txt | Initial local Gunicorn HTTP smoke check |

## Source control and pipeline

| File | Evidence |
| --- | --- |
| ci-pr1-all-checks-passed.png | Successful checks for the CI correction pull request |
| ghcr-publish-success.png | Container image publication to GHCR |
| pr3-checks-passed.png | Infrastructure and deployment pull-request checks |
| pr3-merged.png | Infrastructure and deployment pull request merged |
| aws-automated-deployment-success.png | Successful automated AWS deployment |
| pr4-checks-passed.png | Monitoring and logging pull-request checks |
| grafana-fix-deployment-success.png | Successful main-branch pipeline after the permanent Grafana fix |

Pull requests and workflow history provide additional context:
https://github.com/l00068839/atu-request-tracker/pulls?q=is%3Apr+is%3Aclosed
https://github.com/l00068839/atu-request-tracker/actions

Workflow artifacts retain test reports, coverage, container logs, the published image digest and deployment results. Download availability depends on GitHub artifact retention.

## Infrastructure and application

| File | Evidence |
| --- | --- |
| terraform-plan.txt | Readable Terraform plan captured before provisioning |
| terraform-outputs.txt | Instance ID and public IP outputs |
| aws-app-running.png | Application accessed through the AWS Systems Manager tunnel |

The public IP is not a public application endpoint. The security group has no inbound rules.

## Monitoring, logging and recovery

| File | Evidence |
| --- | --- |
| monitoring-logging-checks-passed.png | Deployment checks for Prometheus scraping and application-to-Alloy-to-Loki log delivery |
| grafana-dashboard-working.png | Application reachability, request rates, status codes and latency |
| grafana-loki-application-logs.png | Application logs queried through Grafana Explore |
| grafana-outage-alert-firing.png | Application unavailable and one application alert firing during a controlled outage |
| grafana-outage-recovered.png | Application available and no application alerts firing after restoration |

The outage test temporarily scaled the application to zero replicas and restored one replica automatically. It verified the availability alert and recovery. It did not test the high-server-error alert, notification delivery, backup restoration or image rollback.

## Evidence handling

Do not commit credentials, passwords, authorization codes, Terraform state or Kubernetes secrets. Exclude terminal screenshots that display the Grafana password.

Task 4 reflection is maintained separately from this Task 3 implementation evidence.
