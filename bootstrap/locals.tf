locals {
  environments = {
    dev = {
      state_key = "environments/dev/terraform.tfstate"
    }
    test = {
      state_key = "environments/test/terraform.tfstate"
    }
    stage = {
      state_key = "environments/stage/terraform.tfstate"
    }
    prod = {
      state_key = "environments/prod/terraform.tfstate"
    }
  }
  plan_events = toset(["pull_request", "workflow_dispatch"])

  repository_parts        = split("/", var.github_repository)
  github_principal_prefix = "repo:${local.repository_parts[0]}@${var.github_repository_owner_id}/${local.repository_parts[1]}@${var.github_repository_id}"
  plan_audience           = "oci://${var.github_repository}/plan"

  oidc_audiences = concat(
    [local.plan_audience],
    [
      for environment in keys(local.environments) :
      "oci://${var.github_repository}/apply/${environment}"
    ]
  )

  identities = {
    exchange = {
      display_name           = "${var.name_prefix}-exchange"
      impersonating_resource = var.name_prefix
      claim_propagations     = ["ext_aud", "ext_workflow", "ext_environment"]
      claim_validations = {
        repository          = var.github_repository
        repository_owner_id = tostring(var.github_repository_owner_id)
        repository_id       = tostring(var.github_repository_id)
      }
    }
  }

  plan_principal_conditions = {
    for event_name in local.plan_events :
    event_name => join(", ", [
      "request.principal.type = 'identityfederateddomainapp'",
      "request.principal.name = '${event_name == "pull_request" ? "${local.github_principal_prefix}:pull_request" : "${local.github_principal_prefix}:ref:refs/heads/${var.github_default_branch}"}'",
      "request.principal.ext_aud = '${local.plan_audience}'",
      "request.principal.ext_workflow = 'Terraform plan'"
    ])
  }

  apply_principal_conditions = {
    for environment in keys(local.environments) :
    environment => join(", ", [
      "request.principal.type = 'identityfederateddomainapp'",
      "request.principal.name = '${local.github_principal_prefix}:environment:${environment}'",
      "request.principal.ext_aud = 'oci://${var.github_repository}/apply/${environment}'",
      "request.principal.ext_workflow = 'Terraform apply'",
      "request.principal.ext_environment = '${environment}'"
    ])
  }
}
