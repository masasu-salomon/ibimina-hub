# Security

## Automated checks

The `Security Scans` workflow runs on pushes and pull requests targeting `main`.

| Check | Tool | What it scans | Failure threshold |
|---|---|---|---|
| Dependency scan | `npm audit --omit=dev` | Production Node.js dependencies | High or critical vulnerabilities |
| Container scan | Trivy | Image built from the repository Dockerfile | Fixable high or critical vulnerabilities |
| IaC scan | Checkov | Terraform and Dockerfile | Any failed check unless narrowly accepted and documented |
| Secret scan | Gitleaks | Full Git history | Any detected secret |

The thresholds are intended to block serious vulnerabilities and exposed credentials from reaching `main`. Trivy ignores vulnerabilities without an available fix. Exceptions must be specific, explained, and reviewed by the team.

## Latest scan results — 2026-11-09

- Dependency scan (`npm audit --omit=dev`): 0 vulnerabilities found.
- Container scan (Trivy, fixable HIGH and CRITICAL): failed with 29 findings: 28 HIGH and 1 CRITICAL. Remediation and rescan are pending.
- IaC scan (Checkov): 25 checks passed and 1 failed. `CKV_AZURE_119` flags the public IP attached to the VM network interface. The separate SSH exposure check `CKV_AZURE_10` passed. Team decision is pending.
- Secret scan (Gitleaks): not run yet.

## Findings and decisions

The statuses below are temporary. Before merging, update every finding to `Fixed` or `Accepted`, and explain how it was handled. The Trivy rows group findings by package; every ID shown is from the initial local scan.

| Tool | Finding ID | Severity | File, package, or resource | Status | Resolution or reason |
|---|---|---|---|---|---|
| Checkov | `CKV_AZURE_119` | Not provided by local Checkov output | `terraform/modules/compute/main.tf`; VM network interface | Pending team decision | Checkov reports that the interface has a public IP. Confirm with Salomon whether this is accepted for the public demo API. |
| Trivy | `CVE-2026-14456`, `CVE-2026-45447` | HIGH | Alpine `libcrypto3` and `libssl3` in the container image | Pending remediation | Trivy reports fixed versions; update the base image or packages and rescan. |
| Trivy | `CVE-2026-107891` | HIGH | Alpine `musl` and `musl-utils` in the container image | Pending remediation | Trivy reports a fixed version; update the base image or packages and rescan. |
| Trivy | `CVE-2026-85091` | HIGH | Alpine `zlib` in the container image | Pending remediation | Trivy reports a fixed version; update the base image or packages and rescan. |
| Trivy | `CVE-2026-102276`, `CVE-2026-102278`, `CVE-2026-13149`, `CVE-2026-14257`, `CVE-2026-69152` | HIGH | Node package `brace-expansion` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2024-21538` | HIGH | Node package `cross-spawn` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2025-64756` | HIGH | Node package `glob` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2026-69192` | HIGH | Node package `ip-address` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2026-26996`, `CVE-2026-27903`, `CVE-2026-27904` | HIGH | Node package `minimatch` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2026-9496` | HIGH | Node package `pacote` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2026-48815` | HIGH | Node package `sigstore` | Pending remediation | Identify the dependency path, update the affected dependency, and rescan. |
| Trivy | `CVE-2026-59873` | CRITICAL | Node package `tar` | Pending remediation | Trivy reports a fixed version; update the dependency path and rescan. |
| Trivy | `CVE-2026-23745`, `CVE-2026-23950`, `CVE-2026-24842`, `CVE-2026-26960`, `CVE-2026-29786`, `CVE-2026-31802`, `CVE-2026-59874`, `CVE-2026-73566` | HIGH | Node package `tar` | Pending remediation | Trivy reports fixed versions; update the dependency path and rescan. |

### Accepted risks

List only findings the team has explicitly agreed to accept. For each, include its ID, the reason, and the matching `.checkov.yaml` or `.trivyignore` exception.

Currently: no risks have final approval. The public-IP finding remains pending Salomon's decision.

## Previously reported issues
salomon you can check this!!

- **body-parser `GHSA-27r3-jxmh-p828`:** The team handoff says this was fixed in PR #25. Verify the merged fix before submission.
- **Dependabot alert #9:** The team handoff describes this as a low-severity alert. Verify its current status and package in GitHub before submission.

## Blocked pull request demonstration

After the security workflow runs, open a throwaway PR that changes the Terraform SSH rule to allow source `*`. Capture the failed IaC check, then close the demo PR without merging it.

- Demonstration PR: pending
- Screenshot: pending

