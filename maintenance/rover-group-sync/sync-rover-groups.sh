#!/usr/bin/env bash
#
# Inject credentials into LDAP config, sync LDAP groups via oc adm groups sync,
# write one portable Group manifest per file, commit + push.
#
# Intended for use in a Kubernetes CronJob; requires oc, yq (mikefarah v4), git.

set -euo pipefail

# Environment overrides (useful for tests): OC, YQ, GIT, SED, FIND, DATE_CMD,
OC="${OC:-oc}"
YQ="${YQ:-yq}"
GIT="${GIT:-git}"
SED="${SED:-sed}"
FIND="${FIND:-find}"
DATE_CMD="${DATE_CMD:-date}"

SYNC_CONFIG_SOURCE="${SYNC_CONFIG_SOURCE:-/config/ldap-sync-config.yaml}"
LDAP_CA_PATH="${LDAP_CA_PATH:-/secrets/ca.crt}"
GIT_PRIVATE_SSH_PATH="${GIT_PRIVATE_SSH_PATH:-/secrets/git-repo/ssh_private}"
BRANCH="${GIT_BRANCH:-main}"
ENVIRONMENT="${ENVIRONMENT:-staging}"
# Optional: export KUBECONFIG only if your oc build requires an apiserver even for LDAP-only sync.
# [[ -n "${KUBECONFIG:-}" ]] || export KUBECONFIG=/var/run/kubeconfig/kubeconfig

# Check for package requirements
echo "Checking for package requirements..."
if ! command -v "${OC}" >/dev/null; then
    echo "missing oc in PATH" >&2
    exit 1
fi

if ! command -v "${YQ}" >/dev/null; then
    echo "missing yq in PATH" >&2
    exit 1
fi

if ! command -v "${GIT}" >/dev/null; then
    echo "missing git in PATH" >&2
    exit 1
fi

# Check environment variable values
echo "Validating environment variables..."
if [[ ! -f "${SYNC_CONFIG_SOURCE}" ]]; then
    echo "missing LDAP sync config template: ${SYNC_CONFIG_SOURCE}" >&2
    exit 1
fi
if [[ ! -f "${LDAP_CA_PATH}" ]]; then
    echo "missing LDAP CA file: ${LDAP_CA_PATH}" >&2
    exit 1
fi
if [[ ! -f "${GIT_PRIVATE_SSH_PATH}" ]]; then
    echo "missing Git repo SSH private key: ${GIT_PRIVATE_SSH_PATH}" >&2
    exit 1
fi

for _required in GIT_REPO_URL LDAP_DN LDAP_PASSWORD; do
    if [[ -z "${!_required:-}" ]]; then
        echo "${_required} must be set to a non-empty string" >&2
        exit 1
    fi
done

if [[ "${ENVIRONMENT}" != "staging" && "${ENVIRONMENT}" != "production" ]]; then
    echo "ENVIRONMENT must be either staging or production" >&2
    exit 1
fi

# Inject credentials into LDAP config writable copy; ConfigMap mount is read-only
echo "Injecting credentials into LDAP config..."
SYNC_CONFIG_FILE="$(mktemp)"
trap 'rm -f "${SYNC_CONFIG_FILE}"' EXIT
cp "${SYNC_CONFIG_SOURCE}" "${SYNC_CONFIG_FILE}"

export LDAP_PASSWORD LDAP_DN LDAP_CA_PATH
"${YQ}" -i '.bindPassword = strenv(LDAP_PASSWORD)' "${SYNC_CONFIG_FILE}"
"${YQ}" -i '.bindDN = strenv(LDAP_DN)' "${SYNC_CONFIG_FILE}"
"${YQ}" -i '.ca = strenv(LDAP_CA_PATH)' "${SYNC_CONFIG_FILE}"

# Clone branch into work directory (tests may set WORKDIR to a fixed path)
echo "Creating work directory..."
WORKDIR="${WORKDIR:-$(mktemp -d --suffix=-workdir)}"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"

# SSH defaults to ~/.ssh/known_hosts when adding hosts (StrictHostKeyChecking=accept-new).
# Force an explicit known_hosts file under a temporary home directory since HOME will be unset and thus
# ~/.ssh will not be writable.
HOME="$(mktemp -d --suffix=-home)"
trap 'rm -rf "${HOME}"' EXIT
SSH_KNOWN_HOSTS="$(mktemp -p "${HOME}" rover-sync-known_hosts.XXXXXX)"
chmod 600 "${SSH_KNOWN_HOSTS}"
trap 'rm -f "${SYNC_CONFIG_FILE}" "${SSH_KNOWN_HOSTS}"' EXIT

if [[ -z "${GIT_SSH_COMMAND:-}" ]]; then
    export GIT_SSH_COMMAND="ssh -i $(printf '%q' "${GIT_PRIVATE_SSH_PATH}") \
-o StrictHostKeyChecking=accept-new \
-o UserKnownHostsFile=$(printf '%q' "${SSH_KNOWN_HOSTS}")"
fi

"${GIT}" clone --depth 1 --branch "${BRANCH}" "${GIT_REPO_URL}" "${WORKDIR}"
cd "${WORKDIR}"

# Get all Group objects - portable only (no annotations/labels/cluster metadata)
LIST_TMP="$(mktemp)"
trap 'rm -f "${LIST_TMP}" "${SYNC_CONFIG_FILE}" "${SSH_KNOWN_HOSTS}"' EXIT

echo "Retrieving groups from LDAP..."
"${OC}" adm groups sync --sync-config="${SYNC_CONFIG_FILE}" -o yaml | "${YQ}" \
    '.items |= map({"apiVersion": .apiVersion, "kind": .kind, "metadata": {"name": .metadata.name}, "users": (.users // [])})' \
    >"${LIST_TMP}"

COUNT="$("${YQ}" '.items | length' "${LIST_TMP}")"

# Create Group manifests in target directory (and sanitize the group name)
echo "Creating Group manifests in target ${ENVIRONMENT} groups directory..."
TARGET_DIR="${WORKDIR}/components/rover-group-sync/${ENVIRONMENT}/groups/"
mkdir -p "${TARGET_DIR}"
"${FIND}" "${TARGET_DIR}" -maxdepth 1 -type f -name '*.yaml' -delete

i=0
while [[ "${i}" -lt "${COUNT}" ]]; do
    name="$("${YQ}" ".items[${i}].metadata.name" "${LIST_TMP}")"
    safe="$(printf '%s' "${name}" | "${SED}" 's/[^a-zA-Z0-9._-]/_/g')"
    "${YQ}" ".items[${i}]" "${LIST_TMP}" -o yaml >"${TARGET_DIR}/${safe}.yaml"
    i=$((i + 1))
done

# Commit to Git repo if the groups were updated (must match TARGET_DIR tree)
"${GIT}" add "${TARGET_DIR}"
if "${GIT}" diff --cached --quiet; then
    echo "No group manifest changes; skipping commit."
    exit 0
fi

"${GIT}" -c user.email="${GIT_AUTHOR_EMAIL:-group-sync@local}" -c user.name="${GIT_AUTHOR_NAME:-group-sync-bot}" \
    commit -m "chore(groups): sync rover LDAP groups ${BRANCH} $("${DATE_CMD}" -u +%Y-%m-%dT%H:%M:%SZ)"

"${GIT}" push "${GIT_REPO_URL}" "${BRANCH}"
