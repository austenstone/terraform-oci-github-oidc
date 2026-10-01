resource "oci_identity_domains_app" "github" {
  for_each = local.identities

  idcs_endpoint = var.identity_domain_url
  display_name  = each.value.display_name
  description   = "OAuth client for ${each.value.display_name}"
  active        = true

  schemas = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]

  based_on_template {
    value = "CustomWebAppTemplateId"
  }

  is_oauth_client = true
  client_type     = "confidential"
  allowed_grants  = ["client_credentials"]

  lifecycle {
    ignore_changes = [schemas]
  }
}

resource "oci_identity_domains_identity_propagation_trust" "github" {
  for_each = local.identities

  idcs_endpoint = var.identity_domain_url
  name          = each.value.display_name
  description   = "GitHub OIDC trust for ${each.value.display_name}"
  issuer        = "https://token.actions.githubusercontent.com"
  active        = true

  schemas = ["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"]

  type                   = "JWT"
  subject_type           = "Resource"
  allow_impersonation    = true
  impersonating_resource = each.value.impersonating_resource
  public_key_endpoint    = "https://token.actions.githubusercontent.com/.well-known/jwks"

  client_claim_name   = "aud"
  client_claim_values = local.oidc_audiences
  oauth_clients       = [oci_identity_domains_app.github[each.key].name]
  claim_propagations  = each.value.claim_propagations

  dynamic "claim_validations" {
    for_each = each.value.claim_validations

    content {
      name  = claim_validations.key
      value = claim_validations.value
    }
  }

  lifecycle {
    ignore_changes = [schemas]
  }
}
