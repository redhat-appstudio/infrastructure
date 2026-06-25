#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_create_group_manifests_env
}

@test "writes kustomization only when group list is empty" {
  prepare_group_list empty

  run create_group_manifests
  [[ "${status}" -eq 0 ]]
  assert_log_info "Group manifests created in target ${ENVIRONMENT} groups directory."

  groups_dir="$(groups_dir_for_env)"
  mapfile -t yaml_files < <(find "${groups_dir}" -maxdepth 1 -type f -name '*.yaml' | sort)
  [[ "${#yaml_files[@]}" -eq 1 ]]
  [[ "$(basename "${yaml_files[0]}")" == "kustomization.yaml" ]]
  run yq '(.resources // []) | length' "${groups_dir}/kustomization.yaml"
  [[ "${output}" == "0" ]]
  assert_kustomization "${groups_dir}"
}

@test "writes group manifest and kustomization when group list has one item" {
  prepare_group_list single

  run create_group_manifests
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/test-group.yaml" ]]
  run yq '.metadata.name' "${groups_dir}/test-group.yaml"
  [[ "${output}" == "test-group" ]]
  assert_kustomization "${groups_dir}" '["test-group.yaml"]'
}

@test "fails when deleting existing group yaml files under groups directory fails" {
  prepare_group_list single
  echo "# stale manifest" >"${TARGET_DIR}/stale.yaml"
  use_stub find

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to delete existing group yaml files in target directory"
  [[ "${output}" == *"simulated failure deleting existing group yaml files"* ]]
}

@test "fails when yq cannot parse oc group list output (malformed yaml)" {
  inject_ldap_credentials
  TEMP_GROUP_LIST="$(mktemp)"
  printf '%s\n' 'INVALID_YAML: [unclosed' >"${TEMP_GROUP_LIST}"

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to count groups in TEMP_GROUP_LIST"
  [[ "${output}" == *"Error:"* ]]
  [[ "${output}" == *"yaml:"* ]]
}

@test "fails when yq cannot read .items[i].metadata.name" {
  prepare_group_list single
  use_stub yq metadata-name

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to get group name from TEMP_GROUP_LIST"
  [[ "${output}" == *"cannot find .items[i].metadata.name"* ]]
}

@test "fails when sed cannot sanitize the group name for the filename" {
  prepare_group_list single
  use_stub sed

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to sanitize group name"
  [[ "${output}" == *"simulated filename sanitize failure"* ]]
}

@test "fails when kustomize init fails" {
  prepare_group_list single
  use_stub kustomize init

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to initialize Kustomize"
  [[ "${output}" == *"simulated init failure"* ]]
}

@test "fails when kustomize edit add resource fails" {
  prepare_group_list single
  use_stub kustomize edit

  run create_group_manifests
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to add resource to Kustomize"
  [[ "${output}" == *"simulated edit add resource failure"* ]]
}
