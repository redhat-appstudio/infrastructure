#!/usr/bin/env bats
#
# Requires: bats, yq (mikefarah v4), git — for tests that exercise real tools.
# Run: bats maintenance/rover-group-sync/test/sync-rover-groups.bats

load test_helpers

setup() {
  test_root="$(mktemp -d)"
  export SYNC_CONFIG_SOURCE="${test_root}/ldap-sync-config.yaml"
  export LDAP_CA_PATH="${test_root}/ca.crt"
  export GIT_PRIVATE_SSH_PATH="${test_root}/ssh_key"
  cp "${BATS_TEST_DIRNAME}/fixtures/ldap-sync-config.yaml" "${SYNC_CONFIG_SOURCE}"
  : >"${LDAP_CA_PATH}"
  : >"${GIT_PRIVATE_SSH_PATH}"
  export GIT_SSH_PUBLIC_KEY="${test_root}/ssh_public"
  # OpenSSH .pub-style line (type + key + comment); script builds known_hosts as github.com + $1 $2
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test-key" >"${GIT_SSH_PUBLIC_KEY}"
  export LDAP_DN="cn=test-bind,dc=example,dc=test"
  export LDAP_PASSWORD="test-password"
  export WORKDIR="${test_root}/workdir"
  export GIT_BRANCH="${GIT_BRANCH:-main}"
  export ENVIRONMENT="${ENVIRONMENT:-staging}"
  SCRIPT="${BATS_TEST_DIRNAME}/../sync-rover-groups.sh"
  unset REASON
  unset CASE
}

stub_binaries() {
  export OC="/bin/true"
  export YQ="/bin/true"
  export GIT="/bin/true"
}

# --- missing binaries (command -v) ---

@test "fails when yq is not installed (YQ points to missing file)" {
  stub_binaries
  export YQ="${test_root}/no-such-yq"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing yq"* ]]
}

@test "fails when git is not installed (GIT points to missing file)" {
  stub_binaries
  export GIT="${test_root}/no-such-git"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing git"* ]]
}

@test "fails when oc is not installed (OC points to missing file)" {
  stub_binaries
  export OC="${test_root}/no-such-oc"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing oc"* ]]
}

# --- empty environment variables ---

@test "fails when SYNC_CONFIG_SOURCE is empty" {
  stub_binaries
  export SYNC_CONFIG_SOURCE=""
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing LDAP sync config"* ]]
}

@test "fails when LDAP_CA_PATH is empty" {
  stub_binaries
  export LDAP_CA_PATH=""
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing LDAP CA file"* ]]
}

@test "fails when GIT_PRIVATE_SSH_PATH is empty" {
  stub_binaries
  export GIT_PRIVATE_SSH_PATH=""
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing Git repo SSH private key"* ]]
}

@test "fails when GIT_REPO_URL is empty" {
  stub_binaries
  export GIT_REPO_URL=""
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"GIT_REPO_URL must be set"* ]]
}

@test "fails when LDAP_DN is empty" {
  stub_binaries
  export LDAP_DN=""
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"LDAP_DN must be set"* ]]
}

@test "fails when LDAP_PASSWORD is empty" {
  stub_binaries
  export LDAP_PASSWORD=""
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"LDAP_PASSWORD must be set"* ]]
}

@test "fails when ENVIRONMENT is neither 'production' nor 'staging'" {
  stub_binaries
  export GIT_REPO_URL="https://example.invalid/repo.git"
  export ENVIRONMENT="not-an-environment"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ENVIRONMENT must be either staging or production"* ]]
}

# --- missing files ---

@test "fails when SYNC_CONFIG_SOURCE file does not exist" {
  stub_binaries
  export SYNC_CONFIG_SOURCE="${test_root}/no-such-config.yaml"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing LDAP sync config"* ]]
}

@test "fails when LDAP_CA_PATH file does not exist" {
  stub_binaries
  export LDAP_CA_PATH="${test_root}/missing-ca.crt"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing LDAP CA file"* ]]
}

@test "fails when GIT_PRIVATE_SSH_PATH file does not exist" {
  stub_binaries
  export GIT_PRIVATE_SSH_PATH="${test_root}/missing-ssh-key"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"missing Git repo SSH private key"* ]]
}

# --- LDAP template injection (yq) failures ---

@test "fails when injecting LDAP_PASSWORD (yq) fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  stub_binaries
  export REASON=password
  export YQ="${BATS_TEST_DIRNAME}/stubs/stub-yq"
  chmod +x "${YQ}"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"cannot find .bindPassword"* ]]
}

@test "fails when injecting LDAP_DN (yq) fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  stub_binaries
  export REASON=dn
  export YQ="${BATS_TEST_DIRNAME}/stubs/stub-yq"
  chmod +x "${YQ}"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"cannot find .bindDN"* ]]
}

@test "fails when injecting LDAP_CA_PATH (yq) fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  stub_binaries
  export REASON=ca
  export YQ="${BATS_TEST_DIRNAME}/stubs/stub-yq"
  chmod +x "${YQ}"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"cannot find .ca"* ]]
}

# --- git failures ---

@test "fails when git clone fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"
  export OC="/bin/true"
  export YQ="$(command -v yq)"
  export REASON=clone
  export GIT="${BATS_TEST_DIRNAME}/stubs/stub-git"
  chmod +x "${GIT}"
  export GIT_REPO_URL="https://example.invalid/repo.git"
  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated clone failure"* ]]
}

@test "fails when git commit fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export REASON=commit
  export GIT="${BATS_TEST_DIRNAME}/stubs/stub-git"
  chmod +x "${GIT}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated commit failure"* ]]
}

@test "fails when git push fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export REASON=push
  export GIT="${BATS_TEST_DIRNAME}/stubs/stub-git"
  chmod +x "${GIT}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated push failure"* ]]
}

# --- oc adm groups sync failure ---

@test "fails when oc adm groups sync fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=sync-fail
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export GIT="$(command -v git)"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated adm groups sync failure"* ]]
}

# --- existing group files deletion failure

@test "fails when deleting existing group yaml files under groups/ fails" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"
  [[ -n "$(command -v find)" ]] || skip "find not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export GIT="$(command -v git)"
  export FIND="${BATS_TEST_DIRNAME}/stubs/find-and-delete-fail"
  chmod +x "${FIND}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated failure deleting existing group yaml files"* ]]
}

# --- manifest creation failures ---

@test "fails when yq cannot parse oc group list output (malformed yaml)" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=malformed-yaml
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export GIT="$(command -v git)"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"Error:"* ]]
  [[ "${output}" == *"yaml:"* ]]
}

@test "fails when yq cannot read .items[i].metadata.name" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export REASON=metadata-name
  export YQ="${BATS_TEST_DIRNAME}/stubs/stub-yq"
  chmod +x "${YQ}"
  export GIT="$(command -v git)"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"cannot find .items[i].metadata.name"* ]]
}

@test "fails when sed cannot sanitize the group name for the filename" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"
  [[ -n "$(command -v sed)" ]] || skip "sed not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export YQ="$(command -v yq)"
  export GIT="$(command -v git)"
  export SED="${BATS_TEST_DIRNAME}/stubs/stub-sed"
  chmod +x "${SED}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"simulated filename sanitize failure"* ]]
}

# --- success paths ---

@test "syncs groups, writes manifests, commits and pushes with one group" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"

  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  [[ -f "${WORKDIR}/groups/staging/test-group.yaml" ]]
  run yq '.metadata.name' "${WORKDIR}/groups/staging/test-group.yaml"
  [[ "${output}" == "test-group" ]]

  run git -C "${bare}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync rover LDAP groups"* ]]
}

@test "syncs groups, writes manifests, commits and pushes with multiple groups" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=multi
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  [[ -f "${WORKDIR}/groups/staging/rover-alpha.yaml" ]]
  [[ -f "${WORKDIR}/groups/staging/rover-bravo.yaml" ]]

  run yq '.metadata.name' "${WORKDIR}/groups/staging/rover-alpha.yaml"
  [[ "${output}" == "rover-alpha" ]]
  run yq '.users | length' "${WORKDIR}/groups/staging/rover-alpha.yaml"
  [[ "${output}" == "0" ]]

  run yq '.metadata.name' "${WORKDIR}/groups/staging/rover-bravo.yaml"
  [[ "${output}" == "rover-bravo" ]]
  run yq '.users[0]' "${WORKDIR}/groups/staging/rover-bravo.yaml"
  [[ "${output}" == "user-one" ]]
}

@test "syncs groups, writes manifests, commits and pushes when GIT_BRANCH is set" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"
  export GIT_BRANCH="my-branch"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  local tmp_branch
  tmp_branch="$(mktemp -d)"
  git clone -q "file://${bare}" "${tmp_branch}"
  git -C "${tmp_branch}" checkout -b my-branch
  git -C "${tmp_branch}" push -q origin my-branch

  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  [[ -f "${WORKDIR}/groups/staging/test-group.yaml" ]]
  run yq '.metadata.name' "${WORKDIR}/groups/staging/test-group.yaml"
  [[ "${output}" == "test-group" ]]

  run git -C "${bare}" log --oneline -1 my-branch
  [[ "${output}" == *"chore(groups): sync rover LDAP groups my-branch"* ]]
}

@test "syncs groups, writes manifests, commits and pushes when ENVIRONMENT is set" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"
  export ENVIRONMENT="production"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"

  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  [[ -f "${WORKDIR}/groups/production/test-group.yaml" ]]
  run yq '.metadata.name' "${WORKDIR}/groups/production/test-group.yaml"
  [[ "${output}" == "test-group" ]]

  run git -C "${bare}" log --oneline -1
  [[ "${output}" == *"chore(groups): sync rover LDAP groups"* ]]
}

@test "syncs groups, sanitizes metadata.name into a safe filename (sed), writes manifests, commits and pushes with one group" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=sanitize
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"
  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  # konflux:weird/name -> colon and slash become underscores (see sync-rover-groups.sh sed)
  [[ -f "${WORKDIR}/groups/staging/konflux_weird_name.yaml" ]]
  run yq '.metadata.name' "${WORKDIR}/groups/staging/konflux_weird_name.yaml"
  [[ "${output}" == "konflux:weird/name" ]]
}

@test "exits 0 without commit when manifests are unchanged" {
  [[ -n "$(command -v yq)" ]] || skip "yq not installed"
  [[ -n "$(command -v git)" ]] || skip "git not installed"

  export CASE=single
  export OC="${BATS_TEST_DIRNAME}/stubs/stub-oc"
  chmod +x "${OC}"
  export GIT_SSH_COMMAND="true"

  bare="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${bare}"

  export GIT_REPO_URL="file://${bare}"

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]

  run bash "${SCRIPT}"
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No group manifest changes"* ]]
}
