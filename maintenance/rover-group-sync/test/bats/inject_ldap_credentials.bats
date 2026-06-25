#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_inject_ldap_credentials_env
}

@test "injects LDAP credentials into config copy" {
  inject_ldap_credentials
  injected="${WRITEABLE_SYNC_CFG}"
  [[ -f "${injected}" ]]

  run yq '.bindDN' "${injected}"
  [[ "${output}" == "${LDAP_DN}" ]]
  run yq '.bindPassword' "${injected}"
  [[ "${output}" == "${LDAP_PASSWORD}" ]]
  run yq '.ca' "${injected}"
  [[ "${output}" == "${LDAP_CA_PATH}" ]]

  run yq '.bindPassword' "${SYNC_CONFIG_SOURCE}"
  [[ "${output}" == "REPLACE_WITH_BIND_PASSWORD" ]]
}

@test "fails when mktemp cannot create a temp file" {
  use_stub mktemp temp-file

  run inject_ldap_credentials
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to create writable LDAP config copy"
  [[ "${output}" == *"simulated failure creating temp file"* ]]
  [[ -z "${WRITEABLE_SYNC_CFG}" ]]
}

@test "fails when cp cannot copy the LDAP sync config template" {
  cp() {
    if [[ "${1:-}" == "${SYNC_CONFIG_SOURCE}" ]]; then
      echo "cp: simulated copy failure" >&2
      return 1
    fi
    command cp "$@"
  }
  export -f cp

  run inject_ldap_credentials
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to copy LDAP config template"
  [[ "${output}" == *"simulated copy failure"* ]]
}

@test "fails when injecting LDAP_PASSWORD (yq) fails" {
  use_stub yq password

  run inject_ldap_credentials
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to inject LDAP password"
  [[ "${output}" == *"cannot find .bindPassword"* ]]
}

@test "fails when injecting LDAP_DN (yq) fails" {
  use_stub yq dn

  run inject_ldap_credentials
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to inject LDAP DN"
  [[ "${output}" == *"cannot find .bindDN"* ]]
}

@test "fails when injecting LDAP_CA_PATH (yq) fails" {
  use_stub yq ca

  run inject_ldap_credentials
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to inject LDAP CA path"
  [[ "${output}" == *"cannot find .ca"* ]]
}
