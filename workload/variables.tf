variable "region" {
  description = "OCI region."
  type        = string
}

variable "parent_compartment_id" {
  description = "Parent compartment containing the four environment compartments."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be dev, test, stage, or prod."
  }
}

variable "vcn_cidr" {
  description = "CIDR for the environment VCN."
  type        = string
}

variable "dns_label" {
  description = "DNS label for the environment VCN."
  type        = string
}

variable "display_name" {
  description = "Display name for the environment VCN."
  type        = string
}

variable "owner" {
  description = "Team responsible for the environment."
  type        = string
}

variable "cost_center" {
  description = "Cost allocation identifier."
  type        = string
}

variable "service_tier" {
  description = "Service criticality tier."
  type        = string
}

variable "data_classification" {
  description = "Highest data classification permitted in the environment."
  type        = string
}

variable "change_tier" {
  description = "Change-control tier for the environment."
  type        = string
}

