# Rover Group Sync

## `sync-rover-groups.sh`

Bash script intended to run in a Kubernetes CronJob (see `Dockerfile`) It:

1. **Validates** that `oc`, `yq` (mikefarah v4), and `git` are available, and that required paths and environment variables are present.
2. **Prepares LDAP sync config** by copying the LDAP sync template and injecting `LDAP_PASSWORD`, `LDAP_DN`, and the CA path with `yq` in-place edits.
3. **Clones** the target Git repository (branch from `GIT_BRANCH`, default `main`) into a work directory.
4. **Syncs OpenShift Groups from LDAP** with `oc adm groups sync`, normalizes the `List` output with `yq`, and writes **one YAML file per group** under `groups/<ENVIRONMENT>/`, using a filename derived from `metadata.name` (non-alphanumeric characters sanitized with `sed`).
5. **Commits and pushes** only if `groups/<ENVIEONMENT>` changed; otherwise exits successfully without a commit.

Typical inputs are mounted files (`SYNC_CONFIG_SOURCE`, `LDAP_CA_PATH`, `GIT_REPO_SSH_PATH`) and secrets (`GIT_REPO_URL`, `LDAP_DN`, `LDAP_PASSWORD`, `GIT_PUBLIC_SSH_KEY`). For Git over SSH, the script sets **`StrictHostKeyChecking=yes`** and writes a **temporary `known_hosts`** file whose line is `github.com` plus the key type and base64 key read from **`GIT_SSH_PUBLIC_KEY`**. Do not disable host key verification in production.

The script supports overriding command paths (`OC`, `YQ`, `GIT`, `SED`, `FIND`, `DATE_CMD`, etc.) and `GIT_SSH_COMMAND` for testing or nonstandard installs.

## Tests

Tests are written with [BATS](https://github.com/bats-core/bats-core) and live under `test/`. They use shell stubs (`test/stubs/`) and fixtures (`test/fixtures/`) to simulate `oc`, `git`, `yq`, failures, and local Git remotes without a real cluster or network.

**Requirements to run the suite:**

- `bats` (bats-core)
- `yq` (mikefarah v4)
- `git`
- `sed` and `find` (for tests that exercise those code paths)

Install BATS with your OS package manager (for example `dnf install bats` on Fedora) or install [bats-core from GitHub](https://github.com/bats-core/bats-core#installing-bats-from-source).

**Run all tests** from the repository root:

```bash
bats maintenance/rover-group-sync/test/sync-rover-groups.bats
```

Or from this directory:

```bash
cd maintenance/rover-group-sync
bats test/sync-rover-groups.bats
```

**Stub environment variables** (used only in tests):

- `CASE` — selects behavior for `stub-oc` (`single`, `multi`, `sanitize`, `sync-fail`, `malformed-yaml`, …).
- `REASON` — selects failure modes for `stub-git` and `stub-yq` (for example `clone`, `commit`, `push`, `password`, `dn`, `ca`, `metadata-name`).

These are unset between tests in `setup()` so cases do not leak into each other.
