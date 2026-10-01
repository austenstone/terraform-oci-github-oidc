resource "oci_identity_compartment" "lab" {
  compartment_id = var.tenancy_ocid
  name           = var.name_prefix
  description    = "Disposable GitHub Actions and Terraform OIDC lab"
  enable_delete  = true
}

resource "oci_identity_compartment" "environment" {
  for_each = local.environments

  compartment_id = oci_identity_compartment.lab.id
  name           = each.key
  description    = "${title(each.key)} environment for the GitHub Terraform OIDC lab"
  enable_delete  = true
}

