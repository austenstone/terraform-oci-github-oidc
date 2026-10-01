terraform {
  required_version = ">= 1.16.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.8"
    }
  }

  backend "oci" {
    auth                = "SecurityToken"
    config_file_profile = "GITHUB_OIDC"
  }
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = "GITHUB_OIDC"
  region              = var.region
}

