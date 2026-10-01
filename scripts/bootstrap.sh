#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/.." && pwd)"
bootstrap_dir="${root_dir}/bootstrap"
profile="${1:-GITHUB_OCI_LAB}"

for command in gh jq oci terraform; do
  command -v "${command}" >/dev/null || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
default_branch="$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')"

tenancy_ocid="$(
  awk -v profile="${profile}" '
    $0 == "[" profile "]" { in_profile = 1; next }
    /^\[/ { in_profile = 0 }
    in_profile && /^tenancy=/ { sub(/^tenancy=/, ""); print; exit }
  ' "${HOME}/.oci/config"
)"

region="$(
  awk -v profile="${profile}" '
    $0 == "[" profile "]" { in_profile = 1; next }
    /^\[/ { in_profile = 0 }
    in_profile && /^region=/ { sub(/^region=/, ""); print; exit }
  ' "${HOME}/.oci/config"
)"

if [[ -z "${tenancy_ocid}" || -z "${region}" ]]; then
  echo "Profile ${profile} is missing tenancy or region in ~/.oci/config" >&2
  exit 1
fi

identity_domain_url="$(
  oci iam domain list \
    --compartment-id "${tenancy_ocid}" \
    --all \
    --profile "${profile}" \
    --auth security_token \
    --query "data[?type==\`DEFAULT\`].url | [0]" \
    --raw-output
)"

if [[ -z "${identity_domain_url}" || "${identity_domain_url}" == "null" ]]; then
  echo "No default OCI identity domain was found" >&2
  exit 1
fi

terraform -chdir="${bootstrap_dir}" init -input=false
terraform -chdir="${bootstrap_dir}" apply -input=false -auto-approve \
  -var="oci_profile=${profile}" \
  -var="tenancy_ocid=${tenancy_ocid}" \
  -var="region=${region}" \
  -var="identity_domain_url=${identity_domain_url}" \
  -var="github_repository=${repository}" \
  -var="github_default_branch=${default_branch}"

chmod 600 "${bootstrap_dir}/terraform.tfstate"

echo "OCI bootstrap complete. Run scripts/configure-github.sh ${repository}."
