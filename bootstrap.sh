#!/usr/bin/env bash
#
# debian-bootstrap entrypoint.
# Prepares and hardens a fresh Debian 12 server. Must run as root.
#
# Usage:
#   sudo ./bootstrap.sh [--config config/bootstrap.toml] [--dry-run] [--only STEP] [--skip STEP]
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "debian-bootstrap must be run as root (e.g. sudo $0)" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "12" ]]; then
    echo "warning: this tool targets Debian 12 (detected: ${ID:-unknown} ${VERSION_ID:-unknown})" >&2
  fi
else
  echo "warning: cannot read /etc/os-release" >&2
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python3 is required but was not found" >&2
  exit 1
fi

export PYTHONPATH="${SCRIPT_DIR}/src${PYTHONPATH:+:${PYTHONPATH}}"
exec "$PYTHON_BIN" -m debian_bootstrap "$@"
