#!/usr/bin/env bash
#
# Create a swapfile, persist it in fstab, and tune swappiness.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${SWAP_SIZE:=2G}"
: "${SWAP_SWAPPINESS:=10}"

swapfile="/swapfile"

size_mb() {
  local s="$1" n u
  n="$(printf '%s' "$s" | tr -cd '0-9')"
  u="$(printf '%s' "$s" | tr -cd '[:alpha:]')"
  case "${u^^}" in
    T|TB|TIB) echo $((n * 1024 * 1024)) ;;
    G|GB|GIB) echo $((n * 1024)) ;;
    M|MB|MIB|"") echo "${n}" ;;
    *) echo "${n}" ;;
  esac
}

if swapon --show=NAME --noheadings 2>/dev/null | grep -qx "${swapfile}"; then
  log "${swapfile} is already active"
else
  if [[ -f "${swapfile}" ]]; then
    log "${swapfile} already exists"
  else
    if ! run fallocate -l "${SWAP_SIZE}" "${swapfile}"; then
      run dd if=/dev/zero of="${swapfile}" bs=1M count="$(size_mb "${SWAP_SIZE}")" status=none
    fi
  fi
  run chmod 600 "${swapfile}"
  run mkswap "${swapfile}"
  run swapon "${swapfile}"
  log "created and activated ${swapfile} (${SWAP_SIZE})"
fi

append_line /etc/fstab "${swapfile} none swap sw 0 0"

write_file /etc/sysctl.d/99-debian-bootstrap-swap.conf 0644 <<EOF
# Managed by debian-bootstrap. Do not edit by hand.
vm.swappiness = ${SWAP_SWAPPINESS}
EOF

run sysctl --system >/dev/null
log "swap configured (size=${SWAP_SIZE}, swappiness=${SWAP_SWAPPINESS})"
