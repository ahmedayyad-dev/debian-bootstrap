#!/usr/bin/env bash
#
# Create a non-root sudo user and install its SSH public key.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${TARGET_USER:?TARGET_USER is required}"
: "${TARGET_SHELL:=/bin/bash}"
: "${TARGET_GROUPS:=sudo}"
: "${SSH_PUBKEY:=}"
: "${SSH_PUBKEY_PATH:=}"

if [[ "${TARGET_USER}" == "root" ]]; then
  die "TARGET_USER must not be root (this tool creates a non-root sudo user)"
fi

if id "${TARGET_USER}" >/dev/null 2>&1; then
  log "user '${TARGET_USER}' already exists"
else
  run useradd --create-home --shell "${TARGET_SHELL}" "${TARGET_USER}"
  log "created user '${TARGET_USER}'"
fi

for g in ${TARGET_GROUPS}; do
  if ! getent group "${g}" >/dev/null 2>&1; then
    warn "group '${g}' does not exist; skipping"
    continue
  fi
  if id "${TARGET_USER}" >/dev/null 2>&1 && in_group "${TARGET_USER}" "${g}"; then
    log "user '${TARGET_USER}' already in group '${g}'"
  else
    run usermod -aG "${g}" "${TARGET_USER}"
    log "added '${TARGET_USER}' to group '${g}'"
  fi
done

key="${SSH_PUBKEY}"
if [[ -z "${key}" && -n "${SSH_PUBKEY_PATH}" ]]; then
  path="${SSH_PUBKEY_PATH/#\~/${HOME}}"
  if [[ -r "${path}" ]]; then
    key="$(cat "${path}")"
  else
    warn "cannot read SSH public key at ${path}; skipping"
  fi
fi

if [[ -z "${key}" ]]; then
  warn "no SSH public key configured; user will not be able to log in with a key"
  exit 0
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  log "[dry-run] would install SSH public key for '${TARGET_USER}'"
  exit 0
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  die "user '${TARGET_USER}' does not exist; cannot install key"
fi

home="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
sshdir="${home}/.ssh"
auth="${sshdir}/authorized_keys"

install -d -m 0700 -o "${TARGET_USER}" -g "${TARGET_USER}" "${sshdir}"
touch "${auth}"
if grep -qxF "${key}" "${auth}" 2>/dev/null; then
  log "SSH public key already present in ${auth}"
else
  printf '%s\n' "${key}" >>"${auth}"
  log "installed SSH public key in ${auth}"
fi
chmod 0600 "${auth}"
chown "${TARGET_USER}:${TARGET_USER}" "${auth}"
