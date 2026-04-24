# shellcheck shell=bash
# Sourced by sync-rover-groups.bats

init_bare_repo_with_empty_commit() {
  local bare="$1"
  local no_hooks
  no_hooks="$(mktemp -d)"
  git init --bare -b main "${bare}"
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}" || exit 1
    git init -b main
    git -c "core.hooksPath=${no_hooks}" commit --allow-empty -m "init"
    git remote add origin "file://${bare}"
    git push -u origin main
  )
  rm -rf "${tmp}" "${no_hooks}"
}
