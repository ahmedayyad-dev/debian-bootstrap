#!/usr/bin/env bash
#
# Configure UFW: default deny incoming, allow configured ports, enable.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${UFW_PORTS:=22 80 443}"

if have_cmd ufw; then
  log "ufw already installed"
else
  apt_update
  apt_install ufw
fi

already_allowed() {
  ufw status 2>/dev/null | grep -Eq "(^|[[:space:]])$1(/tcp)?[[:space:]]+ALLOW"
}

set_port() {
  local p="$1"
  if have_cmd ufw && already_allowed "${p}"; then
    log "port ${p} already allowed"
  else
    run ufw allow "${p}/tcp"
  fi
}

run ufw default deny incoming
run ufw default allow outgoing
for p in ${UFW_PORTS}; do
  set_port "${p}"
done
run ufw --force enable

log "UFW configured (ports: ${UFW_PORTS})"
