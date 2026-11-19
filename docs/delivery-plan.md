# Delivery status

Reviewed: 19 November 2026.

## Implemented and verified

- Feature branches, commits and pull requests with automated checks.
- Flask create/list API with SQLite persistence and automated tests.
- Ruff, Bandit, pip-audit and pytest quality gates.
- Multi-stage non-root container build, Trivy scanning and HTTP integration checks.
- Publication of the tested image to GHCR and deployment by digest.
- Terraform-managed EC2 instance and security group in AWS Ireland.
- GitHub OIDC authentication and Systems Manager deployment.
- K3s deployment with persistent storage, resource limits and health probes.
- Prometheus scraping and a provisioned Grafana dashboard.
- Application log collection through Alloy into Loki.
- Pipeline checks for metrics scraping and end-to-end log delivery.
- Controlled application outage, availability alert firing and recovery.
- Permanent Grafana plugin-update fix verified through the deployment pipeline.

See evidence/README.md for captured results.

## Implementation limits

This is a single-node teaching deployment with one application replica. Local-path volumes survive pod replacement but do not protect against instance or disk loss.

Terraform uses an existing VPC, subnet and instance profile. IAM/OIDC was configured separately. Terraform state is local. Recreating the instance requires reviewing workflow and IAM instance references.

The API has no user authentication or public HTTPS endpoint. Access uses Systems Manager tunnels.

External alert notifications, automated backups, remote Terraform state and SBOM/provenance are not implemented. Action references and base images are not all pinned to immutable digests.

The availability alert was tested. The high-server-error alert, failed-rollout recovery and restoration of a previous image digest were not tested.

Pull requests were used in an individual project. Independent reviewer approval is not claimed.

## Troubleshooting evidence

Actual failures and repairs are retained in the workflow history. These include CI configuration, container vulnerability scanning and OIDC authentication.

Grafana plugin updates initially failed against its read-only filesystem. Disabling automatic plugin updates restored Prometheus and Loki access. The fix was committed, merged and deployed.

## Remaining submission work

- Merge the final documentation and evidence.
- Check repository links and evidence filenames.
- Create a release tag for the assessed version.
- Record and review the five-minute Task 3 demonstration.
- Confirm submission requirements against the assignment brief.

Task 4 reflection is a separate submission.
