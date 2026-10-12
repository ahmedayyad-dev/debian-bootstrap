#!/usr/bin/env bash
#
# Install and configure fail2ban for sshd.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${F2B_MAXRETRY:=5}"
: "${F2B_BANTIME:=1h}"

if pkg_installed fail2ban; then
  log "fail2ban already installed"
else
  apt_update
  apt_install fail2ban
fi

write_file /etc/fail2ban/jail.local 0644 <<EOF
# Managed by debian-bootstrap. Do not edit by hand.
[DEFAULT]
bantime  = ${F2B_BANTIME}
findtime = 10m
maxretry = ${F2B_MAXRETRY}
backend  = systemd
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port    = ssh
EOF

run systemctl enable fail2ban
run systemctl restart fail2ban

log "fail2ban configured (maxretry=${F2B_MAXRETRY}, bantime=${F2B_BANTIME})"
