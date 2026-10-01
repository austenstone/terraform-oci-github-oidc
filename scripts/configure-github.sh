#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/.." && pwd)"
bootstrap_dir="${root_dir}/bootstrap"
repository="${1:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
default_branch="$(gh repo view "${repository}" --json defaultBranchRef --jq '.defaultBranchRef.name')"

for command in gh jq rg terraform; do
  command -v "${command}" >/dev/null || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

outputs="$(terraform -chdir="${bootstrap_dir}" output -json)"

while IFS=$'\t' read -r name value; do
  gh variable set "${name}" --repo "${repository}" --body "${value}"
done < <(jq -r '.repository_variables.value | to_entries[] | [.key, .value] | @tsv' <<<"${outputs}")

client_identifier="$(jq -r '.oidc_client_identifier.value' <<<"${outputs}")"
printf '%s' "${client_identifier}" |
  gh secret set OCI_OIDC_CLIENT_IDENTIFIER --repo "${repository}"

for environment in dev test stage prod; do
  gh api \
    --method PUT \
    "repos/${repository}/environments/${environment}" \
    --input - >/dev/null <<JSON
{
  "wait_timer": 0,
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
JSON

  if ! gh api "repos/${repository}/environments/${environment}/deployment-branch-policies" \
    --jq '.branch_policies[].name' | rg -Fxq "${default_branch}"; then
    gh api \
      --method POST \
      "repos/${repository}/environments/${environment}/deployment-branch-policies" \
      -f "name=${default_branch}" \
      -f "type=branch" >/dev/null
  fi
done

echo "GitHub repository variables, token-exchange secret, and four Environments are configured."
