#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_validate_requirements_env
  export GIT_REPO_URL="https://example.invalid/repo.git"
}

@test "passes when requirements and environment are valid" {
  run validate_requirements
  [[ "${status}" -eq 0 ]]
  assert_log_info "Package requirements validated."
  assert_log_info "Environment variables validated."
}

@test "fails when yq is not installed (YQ points to missing file)" {
  export YQ="${test_root}/no-such-yq"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing YQ in PATH"
}

@test "fails when git is not installed (GIT points to missing file)" {
  export GIT="${test_root}/no-such-git"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing GIT in PATH"
}

@test "fails when oc is not installed (OC points to missing file)" {
  export OC="${test_root}/no-such-oc"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing OC in PATH"
}

@test "fails when kustomize is not installed (KUSTOMIZE points to missing file)" {
  export KUSTOMIZE="${test_root}/no-such-kustomize"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing KUSTOMIZE in PATH"
}

@test "fails when sed is not installed (SED points to missing file)" {
  export SED="${test_root}/no-such-sed"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing SED in PATH"
}

@test "fails when SYNC_CONFIG_SOURCE is empty" {
  export SYNC_CONFIG_SOURCE=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "SYNC_CONFIG_SOURCE file does not exist:"
}

@test "fails when LDAP_CA_PATH is empty" {
  export LDAP_CA_PATH=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "LDAP_CA_PATH file does not exist:"
}

@test "fails when GIT_PRIVATE_SSH_PATH is empty" {
  export GIT_PRIVATE_SSH_PATH=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "GIT_PRIVATE_SSH_PATH file does not exist:"
}

@test "fails when GIT_REPO_URL is empty" {
  export GIT_REPO_URL=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "GIT_REPO_URL must be set to a non-empty string"
}

@test "fails when LDAP_DN is empty" {
  export LDAP_DN=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "LDAP_DN must be set to a non-empty string"
}

@test "fails when LDAP_PASSWORD is empty" {
  export LDAP_PASSWORD=""

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "LDAP_PASSWORD must be set to a non-empty string"
}

@test "fails when ENVIRONMENT is neither 'production' nor 'staging'" {
  export ENVIRONMENT="not-an-environment"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "ENVIRONMENT must be either staging or production"
}

@test "fails when SYNC_CONFIG_SOURCE file does not exist" {
  export SYNC_CONFIG_SOURCE="${test_root}/no-such-config.yaml"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "SYNC_CONFIG_SOURCE file does not exist: ${SYNC_CONFIG_SOURCE}"
}

@test "fails when LDAP_CA_PATH file does not exist" {
  export LDAP_CA_PATH="${test_root}/missing-ca.crt"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "LDAP_CA_PATH file does not exist: ${LDAP_CA_PATH}"
}

@test "fails when GIT_PRIVATE_SSH_PATH file does not exist" {
  export GIT_PRIVATE_SSH_PATH="${test_root}/missing-ssh-key"

  run validate_requirements
  [[ "${status}" -eq 1 ]]
  assert_log_error "GIT_PRIVATE_SSH_PATH file does not exist: ${GIT_PRIVATE_SSH_PATH}"
}
