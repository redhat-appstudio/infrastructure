#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031,SC2154

load test_helpers

setup() {
  setup_common_test_env
  setup_clone_git_repo_env
}

@test "clones repo and checks out the expected branch" {
  export GIT_SSH_COMMAND="true"

  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  export GIT_REPO_URL="file://${bare_repo}"

  run clone_git_repo
  [[ "${status}" -eq 0 ]]
  assert_log_info "Git repository cloned into work directory ${WORKDIR}."

  [[ -d "${WORKDIR}/.git" ]]
  run git -C "${WORKDIR}" branch --show-current
  [[ "${output}" == "main" ]]
}

@test "fails when branch does not exist" {
  export GIT_SSH_COMMAND="true"
  export GIT_BRANCH="no-such-branch"

  bare_repo="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare_repo}"
  export GIT_REPO_URL="file://${bare_repo}"

  run clone_git_repo
  [[ "${status}" -ne 0 ]]
  assert_log_error "Failed to clone Git repository"
  [[ "${output}" == *"Remote branch no-such-branch not found"* || "${output}" == *"not found in upstream origin"* ]]
}

@test "fails when mktemp cannot create a temporary home directory" {
  use_stub mktemp temp-dir
  export GIT_SSH_COMMAND="true"
  export GIT_REPO_URL="https://example.invalid/repo.git"

  run clone_git_repo
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to create temporary home directory"
  [[ "${output}" == *"simulated failure creating temp directory"* ]]
  [[ -z "${TEMP_HOME}" ]]
}

@test "fails when mktemp cannot create the SSH known_hosts file" {
  use_stub mktemp temp-file
  export GIT_SSH_COMMAND="true"
  export GIT_REPO_URL="https://example.invalid/repo.git"

  run clone_git_repo
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to create temporary known_hosts file"
  [[ "${output}" == *"simulated failure creating temp file"* ]]
  [[ -z "${SSH_KNOWN_HOSTS}" ]]
}

@test "fails when git clone fails" {
  use_stub git clone
  export GIT_REPO_URL="https://example.invalid/repo.git"

  run clone_git_repo
  [[ "${status}" -eq 1 ]]
  assert_log_error "Failed to clone Git repository"
  [[ "${output}" == *"simulated clone failure"* ]]
}
