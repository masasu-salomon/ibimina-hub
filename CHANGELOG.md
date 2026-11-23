# Changelog

All notable changes to Ibimina Hub are recorded here, newest first.

## Summative - 2026-11-18 to 2026-11-23

### Added
- Azure infrastructure for a bastion host, private application VM, load balancer, PostgreSQL and Azure Container Registry. in [PR #37](https://github.com/masasu-salomon/ibimina-hub/pull/37).
- GitHub OIDC authentication for deployments and remote Terraform state.
- Continuous deployment from `main`, including image publishing, Terraform planning, Ansible deployment through the bastion and a smoke test.
- Ansible deployment with Docker Compose and an Ansible lint job.
- PostgreSQL persistence, readiness reporting and JSON request logging. in [PR #38](https://github.com/masasu-salomon/ibimina-hub/pull/38).

### Changed
- Removed the GHCR release workflow production images are published to Azure Container Registry.
- Updated the health endpoint to report the deployed commit SHA.
- Added an operations manual and architecture diagram to `README.md`, with Terraform and Ansible operations guides.
- Documented the summative security scan results in `SECURITY.md`.

## Formative 3 - 2026-11-06 to 2026-11-12

### Added
- Terraform deployment to Azure in [PR #31](https://github.com/masasu-salomon/ibimina-hub/pull/31).
- Ansible roles in [PR #32](https://github.com/masasu-salomon/ibimina-hub/pull/32).
- Security scanning workflow in [PR #33](https://github.com/masasu-salomon/ibimina-hub/pull/33).
- Blocked pull request demonstrations in 
(Note that #34 was closed by the security scan on purpose (not merged))[PR #34](https://github.com/masasu-salomon/ibimina-hub/pull/34) and [PR #36](https://github.com/masasu-salomon/ibimina-hub/pull/36).
- Formative 3 README updates in [PR #35](https://github.com/masasu-salomon/ibimina-hub/pull/35).
- GHCR image publishing in [PR #30](https://github.com/masasu-salomon/ibimina-hub/pull/30).

## Formative 2 - 2026-10-30 to 2026-10-31

### Added
- ESLint in [PR #25](https://github.com/masasu-salomon/ibimina-hub/pull/25).
- Docker Compose in [PR #26](https://github.com/masasu-salomon/ibimina-hub/pull/26).
- CI pipeline in [PR #27](https://github.com/masasu-salomon/ibimina-hub/pull/27).
- Dockerfile hardening in [PR #28](https://github.com/masasu-salomon/ibimina-hub/pull/28).
- Formative 2 README updates and a deliberate lint failure demonstration in [PR #29](https://github.com/masasu-salomon/ibimina-hub/pull/29).

## Formative 1 - 2026-10-21 to 2026-10-23

### Added
- Repository foundation and the savings group module.
- Docker and CI in [PR #17](https://github.com/masasu-salomon/ibimina-hub/pull/17).
- Member registration and contributions in [PR #21](https://github.com/masasu-salomon/ibimina-hub/pull/21).
- Payout rotation and group summaries in [PR #22](https://github.com/masasu-salomon/ibimina-hub/pull/22).
- Project board and README updates in [PR #23](https://github.com/masasu-salomon/ibimina-hub/pull/23) and [PR #24](https://github.com/masasu-salomon/ibimina-hub/pull/24).

