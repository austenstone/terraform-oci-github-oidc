variable "oci_profile" {
  description = "OCI CLI session-token profile used only to bootstrap the tenancy."
  type        = string
  default     = "GITHUB_OCI_LAB"
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID."
  type        = string
}

variable "region" {
  description = "OCI home region."
  type        = string
}

variable "identity_domain_url" {
  description = "OCI Identity Domain URL."
  type        = string
}

variable "github_repository" {
  description = "Repository accepted by the OCI propagation trusts in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use owner/name form."
  }
}

variable "github_default_branch" {
  description = "Default branch allowed to run manual plan jobs."
  type        = string
  default     = "main"
}

variable "name_prefix" {
  description = "Prefix for disposable OCI lab resources."
  type        = string
  default     = "github-terraform-oidc"
}
