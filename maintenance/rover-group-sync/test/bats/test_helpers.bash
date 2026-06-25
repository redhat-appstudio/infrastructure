# shellcheck shell=bash
# Sourced by sync-rover-groups test files.

PKG_REQS=(OC YQ GIT SED KUSTOMIZE FIND MKTEMP)
PER_TEST_VARS=(GIT_REPO_URL TARGET_DIR GIT_BRANCH REASON CASE GIT_SSH_COMMAND BARE_REMOTE_PATH)
# ------------------------------------- Helper Functions -------------------------------------
# Skips the test unless all named tools are on PATH. Takes tool names as arguments.
require_tools() {
  local tool
  for tool in "$@"; do
    command -v "${tool}" >/dev/null 2>&1 || skip "${tool} not installed"
  done
}

# Exports stub environment variables to point at real tools. Takes tool names as arguments.
export_tools() {
  local tool env_var path
  for tool in "$@"; do
    env_var="$(printf '%s' "${tool}" | tr '[:lower:]' '[:upper:]')"
    path="$(command -v "${tool}")"
    export "${env_var}"="${path}"
  done
}

# Maps tool environment variable names to stub script names under STUBS_DIR.
_stub_file_for() {
  case "$1" in
    OC) printf '%s' "stub-oc" ;;
    YQ) printf '%s' "stub-yq" ;;
    GIT) printf '%s' "stub-git" ;;
    MKTEMP) printf '%s' "stub-mktemp" ;;
    KUSTOMIZE) printf '%s' "stub-kustomize" ;;
    SED) printf '%s' "stub-sed" ;;
    FIND) printf '%s' "find-and-delete-fail" ;;
    *) printf 'stub-%s' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" ;;
  esac
}

# Points a tool at its stub script and associated use case (optional).
#   use_stub TOOL              — enable stub with default stub file
#   use_stub TOOL VALUE        — VALUE is the use case to use for the stub
#   use_stub TOOL VALUE TYPE   — TYPE is "reason" (default) or "case", which sets the associated env variable
use_stub() {
  local var_name stub_file mode mode_type
  var_name="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  stub_file="$(_stub_file_for "${var_name}")"

  if [[ $# -ge 2 ]]; then
    mode="$2"
    mode_type="${3:-reason}"
    case "${mode_type}" in
      reason) export REASON="${mode}" ;;
      *)   export CASE="${mode}" ;;
    esac
  fi

  export "${var_name}"="${STUBS_DIR}/${stub_file}"
  chmod +x "${!var_name}"
}

# Returns the path to the groups directory for the current environment.
groups_dir_for_env() {
  printf '%s/components/k8s-groups/%s/rover/groups' "${WORKDIR}" "${ENVIRONMENT}"
}

# Runs the main script with the current environment variables.
run_main() {
  run env GIT_BRANCH="${GIT_BRANCH:-main}" bash "${SCRIPT}"
}

# ------------------------------------- Setup Functions -------------------------------------
# Creates a testing environment and sets up environment variables for all tests.
# Test Git repos are created on a per-test basis (GIT_REPO_URL is not set here).
setup_common_test_env() {
  # Setup testing environment and variables
  test_root="$(mktemp -d)"
  BATS_ABS_TEST_DIR="$(cd "${BATS_TEST_DIRNAME}" && pwd)"
  TEST_ABS_DIR="$(cd "${BATS_ABS_TEST_DIR}/.." && pwd)"
  STUBS_DIR="${TEST_ABS_DIR}/stubs"
  export SCRIPT="${TEST_ABS_DIR}/../sync-rover-groups.sh"

  # Unset test-specific environment variables
  unset "${PER_TEST_VARS[@]}"
  unset "${PKG_REQS[@]}"
  export GIT_BRANCH="main"
  export ENVIRONMENT="staging"

  # Set up environment variables for testing
  export SYNC_CONFIG_SOURCE="${test_root}/ldap-sync-config.yaml"
  export LDAP_CA_PATH="${test_root}/ca.crt"
  export GIT_PRIVATE_SSH_PATH="${test_root}/ssh_key"
  cp "${TEST_ABS_DIR}/fixtures/ldap-sync-config.yaml" "${SYNC_CONFIG_SOURCE}"
  : >"${LDAP_CA_PATH}"
  : >"${GIT_PRIVATE_SSH_PATH}"

  export GIT_SSH_PUBLIC_KEY="${test_root}/ssh_public"
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test-key" >"${GIT_SSH_PUBLIC_KEY}"

  export LDAP_DN="cn=test-bind,dc=example,dc=test"
  export LDAP_PASSWORD="test-password"

  export WORKDIR="${test_root}/workdir"
  mkdir -p "${WORKDIR}"

  export MKTEMP_COUNTER_FILE="${test_root}/mktemp-plain.count"
  : >"${MKTEMP_COUNTER_FILE}"

  # The script path is computed at runtime, so we need to disable SC1090 and SC1091.
  # shellcheck disable=SC1090,SC1091
  source "${SCRIPT}"
}

teardown() {
  [[ -n "${test_root:-}" ]] && rm -rf "${test_root}"
}

# Sets up environment variables for the clone git repo tests.
setup_clone_git_repo_env() {
  require_tools git mktemp
  [[ -f "${GIT_PRIVATE_SSH_PATH}" ]] || skip "GIT_PRIVATE_SSH_PATH does not exist"
  export_tools mktemp git
}

# Sets up environment variables for the commit and push tests.
setup_commit_and_push_env() {
  require_tools git
  [[ -n "${ENVIRONMENT}" ]] || skip "ENVIRONMENT is not set"
  [[ -n "${GIT_BRANCH}" ]] || skip "GIT_BRANCH is not set"
  export_tools git
  export CASE=single
  use_stub oc
  export TARGET_DIR="${WORKDIR}/components/k8s-groups/${ENVIRONMENT}/rover/groups/"
}

# Sets up environment variables for the create group manifests tests.
setup_create_group_manifests_env() {
  require_tools yq kustomize sed find
  export_tools yq find kustomize sed
  export CASE=single
  use_stub oc
  export TARGET_DIR="${WORKDIR}/components/k8s-groups/${ENVIRONMENT}/rover/groups/"
  mkdir -p "${TARGET_DIR}"
}

# Sets up environment variables for the inject ldap credentials tests.
setup_inject_ldap_credentials_env() {
  require_tools yq mktemp
  export_tools yq mktemp
}

# Sets up environment variables for the retrieve groups tests.
setup_retrieve_groups_env() {
  require_tools yq mktemp
  export_tools yq mktemp
  use_stub oc single case
}

# Sets up environment variables for the validate requirements tests.
setup_validate_requirements_env() {
  require_tools oc yq git kustomize sed
  export_tools oc yq git kustomize sed
}

# Sets up environment variables for the main tests.
setup_main_env() {
  require_tools yq git kustomize sed find mktemp
  export_tools yq git kustomize sed find mktemp
  use_stub oc
}

# ------------------------------------- Assertion Functions -------------------------------------
# Bats sets $output after `run`; $test_root is set in setup_common_test_env.
# shellcheck disable=SC2154
# Checks that run output includes log_error / log_info lines from sync-rover-groups.sh.
assert_log_error() {
  [[ "${output}" == *"ERROR: ${1}"* ]]
}

# Checks that run output includes log_info lines from sync-rover-groups.sh.
assert_log_info() {
  [[ "${output}" == *"INFO: ${1}"* ]]
}

# Checks that a kustomization.yaml file exists, is valid, and contains the expected resources.
assert_kustomization() {
  local dir="$1"
  [[ -f "${dir}/kustomization.yaml" ]]
  run yq '.apiVersion' "${dir}/kustomization.yaml"
  [[ "${output}" == "kustomize.config.k8s.io/v1beta1" ]]
  run yq '.kind' "${dir}/kustomization.yaml"
  [[ "${output}" == "Kustomization" ]]

  local expected_resources="${2:-}"
  if [[ -n "${expected_resources}" ]]; then
    run yq -o=json -I=0 '.resources' "${dir}/kustomization.yaml"
    [[ "${output}" == "${expected_resources}" ]]
  fi
}

# ------------------------------------- Prepare Functions -------------------------------------
# Creates a bare Git remote, export GIT_REPO_URL, and set BARE_REMOTE_PATH.
prepare_main_remote() {
  BARE_REMOTE_PATH="$(mktemp -d)/remote.git"
  init_bare_repo_with_empty_commit "${BARE_REMOTE_PATH}"
  export GIT_REPO_URL="file://${BARE_REMOTE_PATH}"
}

# Clones a Git repository and sets GIT_REPO_URL and GIT_SSH_COMMAND.
prepare_cloned_repo() {
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-true}"
  export GIT_REPO_URL="file://$1"
  clone_git_repo
}

# Populates TEMP_GROUP_LIST using the specified oc use case.
prepare_group_list() {
  local mode="${1:-single}"
  inject_ldap_credentials
  use_stub oc
  if [[ "${mode}" == "malformed-yaml" ]]; then
    export REASON=malformed-yaml
    unset CASE
  else
    export CASE="${mode}"
    unset REASON
  fi
  retrieve_groups
}

# Prepares a Git repository with manifests and commits them.
prepare_manifests_in_repo() {
  local mode="${2:-single}"
  prepare_cloned_repo "$1"
  prepare_group_list "${mode}"
  create_group_manifests
}

# Initializes a bare Git repository with an empty commit and a test identity.
init_bare_repo_with_empty_commit() {
  local bare="$1"
  local no_hooks
  no_hooks="$(mktemp -d)"
  local -a git_test_identity=(
    -c "user.email=rover-group-sync@test"
    -c "user.name=rover-group-sync-test"
  )
  git init --bare -b main "${bare}" >/dev/null 2>&1
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}" || exit 1
    git init -b main >/dev/null 2>&1
    git "${git_test_identity[@]}" -c "core.hooksPath=${no_hooks}" \
      commit --allow-empty -m "init" >/dev/null 2>&1
    git remote add origin "file://${bare}"
    git "${git_test_identity[@]}" push -u origin main >/dev/null 2>&1
  )
  rm -rf "${tmp}" "${no_hooks}"
}
