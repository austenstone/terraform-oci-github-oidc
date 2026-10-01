output "vcn_id" {
  description = "Created VCN OCID."
  value       = oci_core_vcn.environment.id
}

output "environment" {
  description = "Environment represented by this state."
  value       = var.environment
}

