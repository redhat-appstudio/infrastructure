#!/usr/bin/env bash
#
# Inject credentials into LDAP config, sync LDAP groups via oc adm groups sync,
# write one portable Group manifest per file, commit + push.
#
# Intended for use in a Kubernetes CronJob; requires oc, yq (mikefarah v4), git, kustomize.

set -euo pipefail

# Environment overrides (useful for tests)
OC="${OC:-oc}"
YQ="${YQ:-yq}"
GIT="${GIT:-git}"
SED="${SED:-sed}"
FIND="${FIND:-find}"
KUSTOMIZE="${KUSTOMIZE:-kustomize}"
MKTEMP="${MKTEMP:-mktemp}"

# Variable defaults
SYNC_CONFIG_SOURCE="${SYNC_CONFIG_SOURCE:-/config/ldap-sync-config.yaml}"
LDAP_CA_PATH="${LDAP_CA_PATH:-/secrets/ca.crt}"
GIT_PRIVATE_SSH_PATH="${GIT_PRIVATE_SSH_PATH:-/secrets/git-repo/ssh_private}"
GIT_BRANCH="${GIT_BRANCH:-main}"
ENVIRONMENT="${ENVIRONMENT:-staging}"

# Temp paths (set as created; cleanup removes whatever exists on any exit).
WRITEABLE_SYNC_CFG=""
SSH_KNOWN_HOSTS=""
TEMP_GROUP_LIST=""
TEMP_HOME=""
RAW_SYNC=""

cleanup() {
    set +e
    [[ -n "${SSH_KNOWN_HOSTS:-}" ]] && rm -f "${SSH_KNOWN_HOSTS}"
    [[ -n "${TEMP_GROUP_LIST:-}" ]] && rm -f "${TEMP_GROUP_LIST}"
    [[ -n "${RAW_SYNC:-}" ]] && rm -f "${RAW_SYNC}"
    [[ -n "${WRITEABLE_SYNC_CFG:-}" ]] && rm -f "${WRITEABLE_SYNC_CFG}"
    [[ -n "${TEMP_HOME:-}" ]] && rm -rf "${TEMP_HOME}"
    true
}

log_info() { echo "INFO: $*"; }
log_error() { echo "ERROR: $*" >&2; }

# Validates package requirements and environment variable values.
# Does not check for find, mktemp, or date since those come with bash.
validate_requirements() {
    local var cmd
    # Check for package requirements
    log_info "Checking for package requirements..."
    for var in OC YQ GIT SED KUSTOMIZE; do
        cmd="${!var}"
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log_error "missing ${var} in PATH"
            return 1
        fi
    done
    log_info "Package requirements validated."

    # Check environment variable values
    log_info "Validating environment variables..."
    for var in SYNC_CONFIG_SOURCE LDAP_CA_PATH GIT_PRIVATE_SSH_PATH; do
        if [[ ! -f "${!var}" ]]; then
            log_error "${var} file does not exist: ${!var}"
            return 1
        fi
    done

    local required
    for required in GIT_REPO_URL LDAP_DN LDAP_PASSWORD; do
        if [[ -z "${!required:-}" ]]; then
            log_error "${required} must be set to a non-empty string"
            return 1
        fi
    done

    if [[ "${ENVIRONMENT}" != "staging" && "${ENVIRONMENT}" != "production" ]]; then
        log_error "ENVIRONMENT must be either staging or production"
        return 1
    fi
    log_info "Environment variables validated."
}

# Injects the LDAP credentials into the LDAP config writable copy
# ConfigMap mount is read-only, so we need to create a writable copy.
inject_ldap_credentials() {
    log_info "Injecting credentials into LDAP config..."
    WRITEABLE_SYNC_CFG="$("${MKTEMP}")" || { 
        log_error "Failed to create writable LDAP config copy"
        return 1
    }
    cp "${SYNC_CONFIG_SOURCE}" "${WRITEABLE_SYNC_CFG}" || {
        log_error "Failed to copy LDAP config template"
        return 1
    }

    export LDAP_PASSWORD LDAP_DN LDAP_CA_PATH
    "${YQ}" -i '.bindPassword = strenv(LDAP_PASSWORD)' "${WRITEABLE_SYNC_CFG}" || {
        log_error "Failed to inject LDAP password"
        return 1
    }
    "${YQ}" -i '.bindDN = strenv(LDAP_DN)' "${WRITEABLE_SYNC_CFG}" || {
        log_error "Failed to inject LDAP DN"
        return 1
    }
    "${YQ}" -i '.ca = strenv(LDAP_CA_PATH)' "${WRITEABLE_SYNC_CFG}" || {
        log_error "Failed to inject LDAP CA path"
        return 1
    }
    log_info "LDAP credentials injected into LDAP config."
}

# Clones the Git repository into the work directory
clone_git_repo() {
    # Force an explicit known_hosts file under a temporary home directory since HOME may be unset and thus
    # ~/.ssh would not be writable.
    TEMP_HOME="$("${MKTEMP}" -d --suffix=-home)" || {
        log_error "Failed to create temporary home directory"
        return 1
    }
    export HOME="${TEMP_HOME}"
    SSH_KNOWN_HOSTS="$("${MKTEMP}" -p "${TEMP_HOME}" rover-sync-known_hosts.XXXXXX)" || {
        log_error "Failed to create temporary known_hosts file"
        return 1
    }
    chmod 600 "${SSH_KNOWN_HOSTS}"

    # Clone branch into work directory
    if [[ -z "${GIT_SSH_COMMAND:-}" ]]; then
        local git_ssh_command
        git_ssh_command="ssh -i $(printf '%q' "${GIT_PRIVATE_SSH_PATH}") \
-o StrictHostKeyChecking=accept-new \
-o UserKnownHostsFile=$(printf '%q' "${SSH_KNOWN_HOSTS}")"
        export GIT_SSH_COMMAND="${git_ssh_command}"
    fi

    WORKDIR="${WORKDIR:-$("${MKTEMP}" -d --suffix=-workdir)}"
    rm -rf "${WORKDIR}"
    "${GIT}" clone --depth 1 --branch "${GIT_BRANCH}" "${GIT_REPO_URL}" "${WORKDIR}" || {
        log_error "Failed to clone Git repository"
        return 1
    }
    cd "${WORKDIR}"
    log_info "Git repository cloned into work directory ${WORKDIR}."
}

# Retrieves Group objects from LDAP with minimal metadata
# Keeps openshift.io/ldap* labels/annotations except sync-time (changes every run)
retrieve_groups() {
    if [[ ! -f "${WRITEABLE_SYNC_CFG:-}" ]]; then
        log_error "missing LDAP sync config: ${WRITEABLE_SYNC_CFG}"
        return 1
    fi
    TEMP_GROUP_LIST="$("${MKTEMP}")" || {
        log_error "Failed to create temporary group list file"
        return 1
    }

    RAW_SYNC="$("${MKTEMP}")" || {
        log_error "Failed to create temporary raw sync output file"
        return 1
    }
    log_info "Retrieving groups from LDAP..."
    if ! "${OC}" adm groups sync --sync-config="${WRITEABLE_SYNC_CFG}" -o yaml >"${RAW_SYNC}"; then
        log_error "Failed to sync groups from LDAP (oc adm groups sync)"
        rm -f "${RAW_SYNC}"
        return 1
    fi

    if ! "${YQ}" '.items |= map({
        "apiVersion": .apiVersion,
        "kind": .kind,
        "metadata": (
            {"name": .metadata.name}
            + ({"labels": (.metadata.labels // {}
                | with_entries(select(.key | test("^openshift\\.io/ldap"))))}
            | select(.labels | length > 0))
            + ({"annotations": (.metadata.annotations // {}
                | with_entries(select((.key | test("^openshift\\.io/ldap")) and (.key != "openshift.io/ldap.sync-time"))))}
            | select(.annotations | length > 0))
        ),
        "users": (.users // [])
        })' "${RAW_SYNC}" >"${TEMP_GROUP_LIST}"; then
        log_error "Failed to normalize LDAP group list (yq)"
        rm -f "${RAW_SYNC}"
        return 1
    fi
    log_info "Groups retrieved from LDAP."
}

# Creates Group manifests and kustomization file in target directory using sanitized file names
create_group_manifests() {
    local count
    count="$("${YQ}" '.items | length' "${TEMP_GROUP_LIST}")" || {
        log_error "Failed to count groups in TEMP_GROUP_LIST"
        return 1
    }

    log_info "Creating Group manifests in target ${ENVIRONMENT} groups directory..."
    TARGET_DIR="${WORKDIR}/components/k8s-groups/${ENVIRONMENT}/rover/groups/"
    mkdir -p "${TARGET_DIR}" || {
        log_error "Failed to create target directory ${TARGET_DIR}"
        return 1
    }
    "${FIND}" "${TARGET_DIR}" -maxdepth 1 -type f -name '*.yaml' -delete || {
        log_error "Failed to delete existing group yaml files in target directory ${TARGET_DIR}"
        return 1
    }

    cd "${TARGET_DIR}"
    "${KUSTOMIZE}" init || {
        log_error "Failed to initialize Kustomize"
        return 1
    }

    local i=0
    local name safe
    while [[ "${i}" -lt "${count}" ]]; do
        name="$("${YQ}" ".items[${i}].metadata.name" "${TEMP_GROUP_LIST}")" || {
            log_error "Failed to get group name from TEMP_GROUP_LIST"
            return 1
        }
        safe="$(printf '%s' "${name}" | "${SED}" 's/[^a-zA-Z0-9._-]/_/g')" || {
            log_error "Failed to sanitize group name"
            return 1
        }
        "${YQ}" ".items[${i}]" "${TEMP_GROUP_LIST}" -o yaml >"${TARGET_DIR}/${safe}.yaml" || {
            log_error "Failed to write group manifest to target directory ${TARGET_DIR}/${safe}.yaml"
            return 1
        }
        "${KUSTOMIZE}" edit add resource "${safe}.yaml" || {
            log_error "Failed to add resource to Kustomize"
            return 1
        }
        i=$((i + 1))
    done
    log_info "Group manifests created in target ${ENVIRONMENT} groups directory."
}

# Commits and pushes the group manifests (if changed) to the Git repository
commit_and_push() {
    # Commit to Git repo if the groups were updated (must match TARGET_DIR tree)
    "${GIT}" add "${TARGET_DIR}" || {
        log_error "Failed to add resources to Git repository"
        return 1
    }
    if "${GIT}" diff --cached --quiet; then
        log_info "No group manifest changes; skipping commit."
        return 0
    fi

    "${GIT}" -c user.email="${GIT_AUTHOR_EMAIL:-rover-group-sync@local}" -c user.name="${GIT_AUTHOR_NAME:-rover-group-sync-bot}" \
        commit -m "chore(groups): sync ${ENVIRONMENT} rover LDAP groups ${GIT_BRANCH} $(date -u +%Y-%m-%dT%H:%M:%SZ)" || {
            log_error "Failed to commit changes to Git repository"
            return 1
        }

    "${GIT}" push "${GIT_REPO_URL}" "${GIT_BRANCH}" || {
        log_error "Failed to push changes to Git repository"
        return 1
    }
    log_info "Changes committed and pushed to Git repository."
}

main() {
    trap cleanup EXIT

    validate_requirements
    inject_ldap_credentials
    clone_git_repo
    retrieve_groups
    create_group_manifests
    commit_and_push

    log_info "Group sync completed successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi