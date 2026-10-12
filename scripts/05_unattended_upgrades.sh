#!/usr/bin/env bash
#
# Enable automatic security updates via unattended-upgrades.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${UU_AUTO_REBOOT:=0}"
: "${UU_REBOOT_TIME:=03:30}"

if pkg_installed unattended-upgrades; then
  log "unattended-upgrades already installed"
else
  apt_update
  apt_install unattended-upgrades apt-listchanges
fi

write_file /etc/apt/apt.conf.d/20auto-upgrades 0644 <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

if [[ "${UU_AUTO_REBOOT}" == "1" ]]; then
  autoremove="true"
  reboot="true"
else
  autoremove="true"
  reboot="false"
fi

write_file /etc/apt/apt.conf.d/52-debian-bootstrap-unattended-upgrades 0644 <<EOF
// Managed by debian-bootstrap. Do not edit by hand.
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=\${distro_codename},label=Debian-Security";
    "origin=Debian,codename=\${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "${autoremove}";
Unattended-Upgrade::Automatic-Reboot "${reboot}";
Unattended-Upgrade::Automatic-Reboot-Time "${UU_REBOOT_TIME}";
EOF

run systemctl enable unattended-upgrades
run systemctl restart unattended-upgrades

log "unattended-upgrades configured (auto-reboot=${UU_AUTO_REBOOT})"
