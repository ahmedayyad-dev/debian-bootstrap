#!/usr/bin/env bash
#
# Install systemd unit templates into /etc/systemd/system.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${TEMPLATES_DIR:?TEMPLATES_DIR is required}"

dest="/etc/systemd/system"
shopt -s nullglob
units=("${TEMPLATES_DIR}"/*.service)

if [[ ${#units[@]} -eq 0 ]]; then
  warn "no systemd templates found in ${TEMPLATES_DIR}"
  exit 0
fi

for f in "${units[@]}"; do
  base="$(basename "${f}")"
  if [[ "${DRY_RUN}" != "1" && -f "${dest}/${base}" ]] && cmp -s "${f}" "${dest}/${base}"; then
    log "${base} unchanged"
    continue
  fi
  backup_file "${dest}/${base}"
  run install -m 0644 "${f}" "${dest}/${base}"
  log "installed ${dest}/${base}"
done

run systemctl daemon-reload
log "systemd templates installed"
