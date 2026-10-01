data "oci_identity_compartments" "environment" {
  compartment_id = var.parent_compartment_id
  name           = var.environment
  state          = "ACTIVE"
}

locals {
  compartment_id = one(data.oci_identity_compartments.environment.compartments).id

  tags = {
    environment         = var.environment
    owner               = var.owner
    cost_center         = var.cost_center
    service_tier        = var.service_tier
    data_classification = var.data_classification
    change_tier         = var.change_tier
    managed_by          = "terraform"
    source              = "github-actions-oidc"
  }
}

resource "oci_core_vcn" "environment" {
  compartment_id = local.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = var.display_name
  dns_label      = var.dns_label
  freeform_tags  = local.tags
}

