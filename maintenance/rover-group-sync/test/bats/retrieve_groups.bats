#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_retrieve_groups_env
}

# Call functions directly on success paths (preserves globals); use run on failure paths.
@test "retrieves a single group from LDAP" {
  inject_ldap_credentials
  use_stub oc single case

  retrieve_groups
  [[ -f "${TEMP_GROUP_LIST}" ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "1" ]]
  run yq '.items[0].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "test-group" ]]
  run yq '.items[0].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "user1" ]]
}

@test "retrieves multiple groups from LDAP" {
  inject_ldap_credentials
  use_stub oc multi case

  retrieve_groups
  [[ -f "${TEMP_GROUP_LIST}" ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "2" ]]
  run yq '.items[0].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "rover-alpha" ]]
  run yq '.items[1].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "rover-bravo" ]]
}

@test "fails when WRITEABLE_SYNC_CFG does not exist" {
  export WRITEABLE_SYNC_CFG="${test_root}/no-such-ldap-sync-config.yaml"

  run retrieve_groups
  [[ "${status}" -eq 1 ]]
  assert_log_error "missing LDAP sync config: ${WRITEABLE_SYNC_CFG}"
  [[ -z "${TEMP_GROUP_LIST}" ]]
}

@test "fails when mktemp cannot create the group list temp file" {
  inject_ldap_credentials
  use_stub mktemp temp-file

  run retrieve_groups
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to create temporary group list file"
  [[ "${output}" == *"simulated failure creating temp file"* ]]
  [[ -z "${TEMP_GROUP_LIST}" ]]
}

@test "fails when oc adm groups sync fails" {
  inject_ldap_credentials
  use_stub oc sync-fail
  unset CASE

  run retrieve_groups
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to sync groups from LDAP (oc adm groups sync)"
  [[ "${output}" == *"simulated adm groups sync failure"* ]]
}

@test "fails when yq cannot normalize LDAP group list" {
  inject_ldap_credentials
  use_stub oc malformed-yaml
  unset CASE

  run retrieve_groups
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to normalize LDAP group list (yq)"
}
