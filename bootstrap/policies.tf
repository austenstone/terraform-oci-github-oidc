resource "oci_identity_policy" "github" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-github"
  description    = "Least-privilege access for GitHub OIDC Terraform jobs"

  statements = concat(
    flatten([
      for event_name in local.plan_events : concat(
        [
          "Allow any-user to inspect compartments in compartment id ${oci_identity_compartment.lab.id} where all { ${local.plan_principal_conditions[event_name]} }",
          "Allow any-user to read virtual-network-family in compartment id ${oci_identity_compartment.lab.id} where all { ${local.plan_principal_conditions[event_name]} }",
          "Allow any-user to read buckets in compartment id ${oci_identity_compartment.lab.id} where all { ${local.plan_principal_conditions[event_name]} }",
          "Allow any-user to read objects in compartment id ${oci_identity_compartment.lab.id} where all { ${local.plan_principal_conditions[event_name]}, target.bucket.name = '${oci_objectstorage_bucket.state.name}' }"
        ],
        [
          for environment, config in local.environments :
          "Allow any-user to manage objects in compartment id ${oci_identity_compartment.lab.id} where all { ${local.plan_principal_conditions[event_name]}, target.bucket.name = '${oci_objectstorage_bucket.state.name}', target.object.name = '${config.state_key}.tflock' }"
        ]
      )
    ]),
    flatten([
      for environment, config in local.environments : [
        "Allow any-user to inspect compartments in compartment id ${oci_identity_compartment.lab.id} where all { ${local.apply_principal_conditions[environment]} }",
        "Allow any-user to manage virtual-network-family in compartment id ${oci_identity_compartment.environment[environment].id} where all { ${local.apply_principal_conditions[environment]} }",
        "Allow any-user to read buckets in compartment id ${oci_identity_compartment.lab.id} where all { ${local.apply_principal_conditions[environment]} }",
        "Allow any-user to read objects in compartment id ${oci_identity_compartment.lab.id} where all { ${local.apply_principal_conditions[environment]}, target.bucket.name = '${oci_objectstorage_bucket.state.name}' }",
        "Allow any-user to manage objects in compartment id ${oci_identity_compartment.lab.id} where all { ${local.apply_principal_conditions[environment]}, target.bucket.name = '${oci_objectstorage_bucket.state.name}', target.object.name = '${config.state_key}' }",
        "Allow any-user to manage objects in compartment id ${oci_identity_compartment.lab.id} where all { ${local.apply_principal_conditions[environment]}, target.bucket.name = '${oci_objectstorage_bucket.state.name}', target.object.name = '${config.state_key}.tflock' }"
      ]
    ])
  )
}
