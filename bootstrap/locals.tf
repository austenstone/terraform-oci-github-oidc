locals {
  environments = toset(["dev", "test", "stage", "prod"])
  plan_events  = toset(["pull_request", "workflow_dispatch"])

  oidc_audiences = concat(
    ["oci://${var.github_repository}/plan"],
    [
      for environment in local.environments :
      "oci://${var.github_repository}/apply/${environment}"
    ]
  )

  identities = {
    exchange = {
      display_name           = "${var.name_prefix}-exchange"
      impersonating_resource = var.name_prefix
      claim_propagations     = ["ext_aud", "ext_event_name", "ext_environment"]
      claim_validations = {
        repository = var.github_repository
      }
    }
  }

  plan_principal_conditions = {
    for event_name in local.plan_events :
    event_name => join(", ", [
      "request.principal.type = 'identityfederateddomainapp'",
      "request.principal.name = '${event_name == "pull_request" ? "repo:${var.github_repository}:pull_request" : "repo:${var.github_repository}:ref:refs/heads/${var.github_default_branch}"}'"
    ])
  }

  apply_principal_conditions = {
    for environment in local.environments :
    environment => join(", ", [
      "request.principal.type = 'identityfederateddomainapp'",
      "request.principal.name = 'repo:${var.github_repository}:environment:${environment}'"
    ])
  }
}
