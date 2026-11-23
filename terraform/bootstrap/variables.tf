variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "ibimina-hub"
}

variable "location" {
  description = "Azure region for the state store."
  type        = string
  default     = "southafricanorth"
}

variable "github_repository" {
  description = "owner/name of the GitHub repository allowed to log in to Azure through OIDC."
  type        = string
  default     = "masasu-salomon/ibimina-hub"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "github_oidc_subject_prefix" {
  description = "Prefix GitHub puts on this repo's OIDC subject. Read it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix"
  type        = string
  default     = "repo:masasu-salomon@180163847/ibimina-hub@1428870229"

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", var.github_oidc_subject_prefix))
    error_message = "Use GitHub's immutable form: repo:owner@owner_id/name@repo_id."
  }
}

variable "github_environment" {
  description = "GitHub environment the CD jobs run in. Only jobs in this environment get an Azure token."
  type        = string
  default     = "production"
}
