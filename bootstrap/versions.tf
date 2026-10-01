terraform {
  required_version = ">= 1.16.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.8"
    }
  }
}

provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = var.oci_profile
  region              = var.region
}

