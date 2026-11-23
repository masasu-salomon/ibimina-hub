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

variable "github_repository_immutable" {
  description = "github_repository in GitHub's immutable OIDC form, owner@owner_id/name@repo_id. Read it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix (drop the leading repo:)"
  type        = string
  default     = "masasu-salomon@180163847/ibimina-hub@1428870229"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", var.github_repository_immutable))
    error_message = "Use GitHub's immutable form: owner@owner_id/name@repo_id."
  }
}

variable "github_environment" {
  description = "GitHub environment the CD jobs run in. Only jobs in this environment get an Azure token."
  type        = string
  default     = "production"
}
