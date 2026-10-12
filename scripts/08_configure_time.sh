#!/usr/bin/env bash
#
# Set the timezone and enable NTP time synchronisation.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${TIMEZONE:=UTC}"
: "${NTP_ENABLED:=1}"

if [[ ! -e "/usr/share/zoneinfo/${TIMEZONE}" ]]; then
  die "unknown timezone '${TIMEZONE}'"
fi

run timedatectl set-timezone "${TIMEZONE}"
log "timezone set to ${TIMEZONE}"

if [[ "${NTP_ENABLED}" == "1" ]]; then
  if pkg_installed systemd-timesyncd; then
    log "systemd-timesyncd already installed"
  else
    apt_update
    apt_install systemd-timesyncd
  fi
  run systemctl enable --now systemd-timesyncd
  run timedatectl set-ntp true
  log "NTP enabled via systemd-timesyncd"
else
  run timedatectl set-ntp false
  log "NTP disabled"
fi
