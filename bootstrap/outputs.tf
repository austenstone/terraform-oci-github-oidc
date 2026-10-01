output "repository_variables" {
  description = "Non-secret GitHub Actions repository variables."
  value = {
    OCI_IDENTITY_DOMAIN_URL   = var.identity_domain_url
    OCI_PARENT_COMPARTMENT_ID = oci_identity_compartment.lab.id
    OCI_REGION                = var.region
    OCI_STATE_BUCKET          = oci_objectstorage_bucket.state.name
    OCI_STATE_NAMESPACE       = data.oci_objectstorage_namespace.this.namespace
    OCI_TENANCY_OCID          = var.tenancy_ocid
  }
}

output "oidc_client_identifier" {
  description = "Token-exchange OAuth client in client_id:client_secret form."
  value       = "${oci_identity_domains_app.github["exchange"].name}:${oci_identity_domains_app.github["exchange"].client_secret}"
  sensitive   = true
}

output "oidc_audiences" {
  description = "Distinct GitHub OIDC audiences accepted by the trust."
  value       = local.oidc_audiences
}

output "environment_compartment_ids" {
  description = "OCI compartment OCIDs created for each environment."
  value = {
    for environment in keys(local.environments) :
    environment => oci_identity_compartment.environment[environment].id
  }
}
