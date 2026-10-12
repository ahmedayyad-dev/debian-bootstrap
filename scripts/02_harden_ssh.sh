#!/usr/bin/env bash
#
# Harden sshd: disable root login and password authentication.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${SSH_PORT:=22}"
: "${SSH_PERMIT_ROOT_LOGIN:=no}"
: "${SSH_PASSWORD_AUTH:=no}"

conf="/etc/ssh/sshd_config.d/99-debian-bootstrap.conf"
backup_file "${conf}"

write_file "${conf}" 0600 <<EOF
# Managed by debian-bootstrap. Do not edit by hand.
Port ${SSH_PORT}
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
PasswordAuthentication ${SSH_PASSWORD_AUTH}
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
LoginGraceTime 30
EOF

if [[ "${DRY_RUN}" == "1" ]]; then
  log "[dry-run] would validate sshd config and reload ssh"
  exit 0
fi

if ! sshd -t; then
  die "sshd configuration is invalid; not reloading"
fi
log "sshd configuration valid"

if systemctl reload ssh 2>/dev/null; then
  log "reloaded ssh"
elif systemctl reload sshd 2>/dev/null; then
  log "reloaded sshd"
else
  run systemctl restart ssh 2>/dev/null || run systemctl restart sshd
fi

log "SSH hardened (port ${SSH_PORT}, root login ${SSH_PERMIT_ROOT_LOGIN}, password auth ${SSH_PASSWORD_AUTH})"
