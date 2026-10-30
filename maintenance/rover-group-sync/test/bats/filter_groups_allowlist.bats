#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_filter_groups_allowlist_env
}

@test "does nothing when GROUPS_ALLOWLIST is unset" {
  prepare_group_list multi

  run filter_groups_allowlist
  [[ "${status}" -eq 0 ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "2" ]]
}

@test "does nothing when GROUPS_ALLOWLIST is empty" {
  prepare_group_list multi
  export GROUPS_ALLOWLIST=""

  run filter_groups_allowlist
  [[ "${status}" -eq 0 ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "2" ]]
}

@test "keeps only allowlisted groups" {
  prepare_group_list multi
  export GROUPS_ALLOWLIST="rover-bravo"

  run filter_groups_allowlist
  [[ "${status}" -eq 0 ]]
  assert_log_info "Groups filtered by allowlist."
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "1" ]]
  run yq '.items[0].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "rover-bravo" ]]
}

@test "keeps multiple allowlisted groups and trims whitespace" {
  prepare_group_list multi
  export GROUPS_ALLOWLIST=" rover-alpha , rover-bravo "

  run filter_groups_allowlist
  [[ "${status}" -eq 0 ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "2" ]]
  run yq '.items[0].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "rover-alpha" ]]
  run yq '.items[1].metadata.name' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "rover-bravo" ]]
}

@test "drops all groups when allowlist matches nothing" {
  prepare_group_list multi
  export GROUPS_ALLOWLIST="no-such-group"

  run filter_groups_allowlist
  [[ "${status}" -eq 0 ]]
  run yq '.items | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "0" ]]
}
