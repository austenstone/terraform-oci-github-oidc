#!/usr/bin/env bash

set -euo pipefail

for command in curl jq openssl; do
  command -v "${command}" >/dev/null || {
    echo "Missing required runner command: ${command}" >&2
    exit 1
  }
done

required_variables=(
  ACTIONS_ID_TOKEN_REQUEST_TOKEN
  ACTIONS_ID_TOKEN_REQUEST_URL
  GITHUB_ENV
  OCI_IDENTITY_DOMAIN_URL
  OCI_OIDC_AUDIENCE
  OCI_OIDC_CLIENT_IDENTIFIER
  OCI_PROFILE
  OCI_REGION
  OCI_RESOURCE_TYPE
  OCI_RPST_EXPIRATION
  OCI_TENANCY_OCID
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required environment variable: ${variable}" >&2
    exit 1
  fi
done

if [[ ! "${OCI_IDENTITY_DOMAIN_URL}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ]]; then
  echo "OCI_IDENTITY_DOMAIN_URL must be an HTTPS origin without a path" >&2
  exit 1
fi

if [[ "${OCI_OIDC_CLIENT_IDENTIFIER}" != *:* ]]; then
  echo "OCI_OIDC_CLIENT_IDENTIFIER must use client_id:client_secret form" >&2
  exit 1
fi

if [[ ! "${OCI_RPST_EXPIRATION}" =~ ^[0-9]+$ ]] ||
  ((OCI_RPST_EXPIRATION < 20 || OCI_RPST_EXPIRATION > 720)); then
  echo "OCI_RPST_EXPIRATION must be between 20 and 720 minutes" >&2
  exit 1
fi

if [[ ! "${OCI_PROFILE}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "OCI_PROFILE contains unsupported characters" >&2
  exit 1
fi

identity_domain_url="${OCI_IDENTITY_DOMAIN_URL%/}"
oci_dir="${HOME}/.oci"
session_dir="${oci_dir}/sessions/${OCI_PROFILE}"
config_path="${oci_dir}/config"

umask 077
mkdir -p "${session_dir}"

private_key_tmp="$(mktemp "${session_dir}/private_key.pem.XXXXXX")"
public_key_tmp="$(mktemp "${session_dir}/public_key.pem.XXXXXX")"
token_tmp="$(mktemp "${session_dir}/token.XXXXXX")"
oidc_response_tmp="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/github-oidc.XXXXXX")"
exchange_response_tmp="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/oci-rpst.XXXXXX")"
config_tmp="$(mktemp "${oci_dir}/config.XXXXXX")"

cleanup() {
  rm -f \
    "${oidc_response_tmp}" \
    "${exchange_response_tmp}" \
    "${config_tmp}" \
    "${private_key_tmp}" \
    "${public_key_tmp}" \
    "${token_tmp}"
}
trap cleanup EXIT

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -out "${private_key_tmp}" \
  2>/dev/null
openssl pkey \
  -in "${private_key_tmp}" \
  -pubout \
  -out "${public_key_tmp}" \
  2>/dev/null

public_key="$(
  openssl pkey \
    -in "${private_key_tmp}" \
    -pubout \
    -outform DER \
    2>/dev/null |
    openssl base64 -A
)"
fingerprint="$(
  openssl pkey \
    -in "${private_key_tmp}" \
    -pubout \
    -outform DER \
    2>/dev/null |
    openssl dgst -md5 -c |
    awk '{print $2}'
)"
client_authorization="$(
  printf '%s' "${OCI_OIDC_CLIENT_IDENTIFIER}" |
    openssl base64 -A
)"

oidc_status="$(
  curl \
    --connect-timeout 15 \
    --max-time 60 \
    --proto '=https' \
    --silent \
    --show-error \
    --output "${oidc_response_tmp}" \
    --write-out '%{http_code}' \
    --get \
    --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    --data-urlencode "audience=${OCI_OIDC_AUDIENCE}" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}"
)"

if [[ "${oidc_status}" != "200" ]]; then
  echo "GitHub OIDC token request failed with HTTP ${oidc_status}" >&2
  exit 1
fi

github_token="$(jq -er '.value' "${oidc_response_tmp}")"
echo "::add-mask::${github_token}"

exchange_status="$(
  curl \
    --connect-timeout 15 \
    --max-time 60 \
    --proto '=https' \
    --silent \
    --show-error \
    --output "${exchange_response_tmp}" \
    --write-out '%{http_code}' \
    --request POST \
    --header "Authorization: Basic ${client_authorization}" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
    --data-urlencode "requested_token_type=urn:oci:token-type:oci-rpst" \
    --data-urlencode "public_key=${public_key}" \
    --data-urlencode "subject_token=${github_token}" \
    --data-urlencode "subject_token_type=jwt" \
    --data-urlencode "res_type=${OCI_RESOURCE_TYPE}" \
    --data-urlencode "rpst_exp=${OCI_RPST_EXPIRATION}" \
    "${identity_domain_url}/oauth2/v1/token"
)"

if [[ "${exchange_status}" != "200" ]]; then
  echo "OCI token exchange failed with HTTP ${exchange_status}" >&2
  exit 1
fi

rpst="$(jq -er '.token' "${exchange_response_tmp}")"
echo "::add-mask::${rpst}"
printf '%s' "${rpst}" >"${token_tmp}"

if [[ -f "${config_path}" ]]; then
  awk -v profile="${OCI_PROFILE}" '
    $0 == "[" profile "]" { skip = 1; next }
    /^\[/ { skip = 0 }
    !skip { print }
  ' "${config_path}" >"${config_tmp}"
fi

cat >>"${config_tmp}" <<EOF
[${OCI_PROFILE}]
user=not used
fingerprint=${fingerprint}
key_file=${session_dir}/private_key.pem
tenancy=${OCI_TENANCY_OCID}
region=${OCI_REGION}
security_token_file=${session_dir}/token
EOF

chmod 600 \
  "${private_key_tmp}" \
  "${public_key_tmp}" \
  "${token_tmp}" \
  "${config_tmp}"
mv -f "${private_key_tmp}" "${session_dir}/private_key.pem"
mv -f "${public_key_tmp}" "${session_dir}/public_key.pem"
mv -f "${token_tmp}" "${session_dir}/token"
mv -f "${config_tmp}" "${config_path}"

cat >>"${GITHUB_ENV}" <<EOF
OCI_CLI_AUTH=security_token
OCI_CLI_CONFIG_FILE=${config_path}
OCI_CLI_PROFILE=${OCI_PROFILE}
OCI_CONFIG_FILE=${config_path}
EOF

unset client_authorization github_token public_key rpst
echo "Configured short-lived OCI RPST authentication for profile ${OCI_PROFILE}."
