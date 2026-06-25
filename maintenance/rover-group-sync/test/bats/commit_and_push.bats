#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_commit_and_push_env
}

@test "commits and pushes manifest changes to the remote" {
  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  prepare_manifests_in_repo "${bare_repo}"

  run commit_and_push
  [[ "${status}" -eq 0 ]]
  assert_log_info "Changes committed and pushed to Git repository."
  [[ "${output}" != *"No group manifest changes"* ]]

  [[ -f "${WORKDIR}/components/k8s-groups/staging/rover/groups/test-group.yaml" ]]
  run git -C "${bare_repo}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync $ENVIRONMENT rover LDAP groups"* ]]
}

@test "exits 0 without commit when manifests are unchanged" {
  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  prepare_manifests_in_repo "${bare_repo}" empty

  run commit_and_push
  [[ "${status}" -eq 0 ]]

  run git -C "${bare_repo}" rev-list --count main
  commit_count_after_first="${output}"

  run commit_and_push
  [[ "${status}" -eq 0 ]]
  assert_log_info "No group manifest changes; skipping commit."

  run git -C "${bare_repo}" rev-list --count main
  [[ "${output}" == "${commit_count_after_first}" ]]
}

@test "fails when git add fails" {
  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  prepare_manifests_in_repo "${bare_repo}"
  use_stub git add

  run commit_and_push
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to add resources to Git repository"
  [[ "${output}" == *"simulated add failure"* ]]
}

@test "fails when git commit fails" {
  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  prepare_manifests_in_repo "${bare_repo}"
  use_stub git commit

  run commit_and_push
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to commit changes to Git repository"
  [[ "${output}" == *"simulated commit failure"* ]]
}

@test "fails when git push fails" {
  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  prepare_manifests_in_repo "${bare_repo}"
  use_stub git push

  run commit_and_push
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to push changes to Git repository"
  [[ "${output}" == *"simulated push failure"* ]]
}
