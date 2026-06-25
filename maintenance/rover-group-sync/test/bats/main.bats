#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_main_env
  export GIT_SSH_COMMAND="true"
}

@test "syncs groups, writes manifests, commits and pushes with one group" {
  export CASE=single
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]
  assert_log_info "Group sync completed successfully."

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/test-group.yaml" ]]
  run yq '.metadata.name' "${groups_dir}/test-group.yaml"
  [[ "${output}" == "test-group" ]]
  assert_kustomization "${groups_dir}" '["test-group.yaml"]'

  run git -C "${BARE_REMOTE_PATH}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups"* ]]
}

@test "filters group metadata to stable openshift.io/ldap labels and annotations" {
 export CASE=ldap-metadata
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  manifest="$(groups_dir_for_env)/konflux-admins.yaml"
  [[ -f "${manifest}" ]]

  run yq '.metadata.labels."openshift.io/ldap.host"' "${manifest}"
  [[ "${output}" == "ldap.corp.redhat.com" ]]
  run yq '.metadata.annotations."openshift.io/ldap.uid"' "${manifest}"
  [[ "${output}" == "cn=konflux-admins,ou=adhoc,ou=managedGroups,dc=redhat,dc=com" ]]
  run yq '.metadata.annotations."openshift.io/ldap.url"' "${manifest}"
  [[ "${output}" == "ldaps://ldap.corp.redhat.com" ]]

  run yq '.metadata.labels | has("app.kubernetes.io/managed-by")' "${manifest}"
  [[ "${output}" == "false" ]]
  run yq '.metadata.annotations | has("kubectl.kubernetes.io/last-applied-configuration")' "${manifest}"
  [[ "${output}" == "false" ]]
  run yq '.metadata.annotations | has("openshift.io/ldap.sync-time")' "${manifest}"
  [[ "${output}" == "false" ]]
  run yq '.metadata.labels | length' "${manifest}"
  [[ "${output}" == "1" ]]
  run yq '.metadata.annotations | length' "${manifest}"
  [[ "${output}" == "2" ]]
}

@test "syncs groups, writes manifests, commits and pushes with multiple groups" {
  export CASE=multi
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/rover-alpha.yaml" ]]
  [[ -f "${groups_dir}/rover-bravo.yaml" ]]

  run yq '.metadata.name' "${groups_dir}/rover-alpha.yaml"
  [[ "${output}" == "rover-alpha" ]]
  run yq '.users | length' "${groups_dir}/rover-alpha.yaml"
  [[ "${output}" == "0" ]]
  run yq '.metadata.name' "${groups_dir}/rover-bravo.yaml"
  [[ "${output}" == "rover-bravo" ]]
  run yq '.users[0]' "${groups_dir}/rover-bravo.yaml"
  [[ "${output}" == "user-one" ]]
  assert_kustomization "${groups_dir}" '["rover-alpha.yaml","rover-bravo.yaml"]'
}

@test "syncs groups, writes manifests, commits and pushes when GIT_BRANCH is set" {
  export CASE=single
  export GIT_BRANCH="my-branch"

  prepare_main_remote
  tmp_branch="$(mktemp -d)"
  git clone -q "file://${BARE_REMOTE_PATH}" "${tmp_branch}"
  git -C "${tmp_branch}" checkout -b my-branch
  git -C "${tmp_branch}" push -q origin my-branch
  rm -rf "${tmp_branch}"

  run_main
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/test-group.yaml" ]]
  run git -C "${WORKDIR}" branch --show-current
  [[ "${output}" == "my-branch" ]]
  run git -C "${WORKDIR}" log -1 --format=%s
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups my-branch"* ]]
  run git -C "${BARE_REMOTE_PATH}" log --oneline -1 my-branch
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups"* ]]
}

@test "syncs groups, writes manifests, commits and pushes when ENVIRONMENT is set" {
  export CASE=single
  export ENVIRONMENT="production"
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/test-group.yaml" ]]
  run git -C "${BARE_REMOTE_PATH}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups"* ]]
}

@test "syncs groups, sanitizes metadata.name into a safe filename (sed), writes manifests, commits and pushes with one group" {
  export CASE=sanitize
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/konflux_weird_name.yaml" ]]
  run yq '.metadata.name' "${groups_dir}/konflux_weird_name.yaml"
  [[ "${output}" == "konflux:weird/name" ]]
  assert_kustomization "${groups_dir}" '["konflux_weird_name.yaml"]'
}

@test "syncs zero groups, writes kustomization only, and treats resources as empty" {
  export CASE=empty
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  groups_dir="$(groups_dir_for_env)"
  [[ -f "${groups_dir}/kustomization.yaml" ]]
  mapfile -t yaml_files < <(find "${groups_dir}" -maxdepth 1 -type f -name '*.yaml' | sort)
  [[ "${#yaml_files[@]}" -eq 1 ]]
  [[ "$(basename "${yaml_files[0]}")" == "kustomization.yaml" ]]
  run yq '(.resources // []) | length' "${groups_dir}/kustomization.yaml"
  [[ "${output}" == "0" ]]
  assert_kustomization "${groups_dir}"

  run git -C "${BARE_REMOTE_PATH}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups"* ]]
}

@test "exits 0 without commit when manifests are unchanged" {
  export CASE=single
  prepare_main_remote

  run_main
  [[ "${status}" -eq 0 ]]

  run_main
  [[ "${status}" -eq 0 ]]
  assert_log_info "No group manifest changes; skipping commit."
}

@test "main exits 1 when git clone fails" {
  export CASE=single
  prepare_main_remote
  use_stub git clone

  run_main
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to clone Git repository"
  [[ "${output}" == *"simulated clone failure"* ]]
}
