#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_apply_username_prefix_env
}

@test "does nothing when USERNAME_PREFIX is unset" {
  prepare_group_list single

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  run yq '.items[0].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "user1" ]]
}

@test "does nothing when USERNAME_PREFIX is empty" {
  prepare_group_list single
  export USERNAME_PREFIX=""

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  run yq '.items[0].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "user1" ]]
}

@test "prefixes each username in a single group" {
  prepare_group_list single
  export USERNAME_PREFIX="redhat:"

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  assert_log_info "Username prefix applied."
  run yq '.items[0].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "redhat:user1" ]]
}

@test "prefixes usernames across multiple groups" {
  prepare_group_list multi
  export USERNAME_PREFIX="idp:"

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  run yq '.items[0].users | length' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "0" ]]
  run yq '.items[1].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "idp:user-one" ]]
}

@test "leaves groups with no users unchanged" {
  prepare_group_list multi
  export USERNAME_PREFIX="pfx:"

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  run yq '.items[0].users' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "[]" ]]
}

@test "prefixes multiple users in one group" {
  prepare_group_list multi-users
  export USERNAME_PREFIX="corp:"

  run apply_username_prefix
  [[ "${status}" -eq 0 ]]
  run yq '.items[0].users[0]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "corp:alice" ]]
  run yq '.items[0].users[1]' "${TEMP_GROUP_LIST}"
  [[ "${output}" == "corp:bob" ]]
}
