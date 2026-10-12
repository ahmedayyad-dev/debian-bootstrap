#!/usr/bin/env bash
#
# Shared helpers for debian-bootstrap step scripts.
# Every step script sources this file. Behaviour:
#   DRY_RUN=1  -> print actions, change nothing
#   LOG_FILE   -> optional path to append structured log lines

# shellcheck shell=bash

: "${DRY_RUN:=0}"
: "${LOG_FILE:=}"

_ts() { date '+%Y-%m-%d %H:%M:%S'; }

_logfile() {
  [[ -n "${LOG_FILE}" ]] || return 0
  printf '%s [%s] %s\n' "$(_ts)" "$1" "$2" >>"${LOG_FILE}" 2>/dev/null || true
}

log()  { printf '%s [INFO ] %s\n' "$(_ts)" "$*"; _logfile INFO  "$*"; }
warn() { printf '%s [WARN ] %s\n' "$(_ts)" "$*" >&2; _logfile WARN "$*"; }
err()  { printf '%s [ERROR] %s\n' "$(_ts)" "$*" >&2; _logfile ERROR "$*"; }
die()  { err "$*"; exit 1; }

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "must run as root"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# run <cmd...> : execute a command, honouring DRY_RUN.
run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    printf '%s [DRY  ] %s\n' "$(_ts)" "$*"
    _logfile DRY "$*"
    return 0
  fi
  log "+ $*"
  "$@"
}

# run_shell <string> : execute a shell pipeline, honouring DRY_RUN.
run_shell() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    printf '%s [DRY  ] %s\n' "$(_ts)" "$*"
    _logfile DRY "$*"
    return 0
  fi
  log "+ $*"
  bash -c "$*"
}

APT_UPDATED=0
apt_update() {
  [[ "${APT_UPDATED}" == "1" ]] && return 0
  run apt-get update -qq
  APT_UPDATED=1
}

apt_install() {
  DEBIAN_FRONTEND=noninteractive run apt-get install -y -qq --no-install-recommends "$@"
}

# backup_file <path> : timestamped backup if the file exists.
backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would back up $f"
    return 0
  fi
  local b="${f}.bak.$(date +%Y%m%d%H%M%S)"
  cp -a "$f" "$b"
  log "backup: $b"
}

# write_file <path> [mode] : write stdin to path (creates dirs).
write_file() {
  local path="$1" mode="${2:-0644}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would write $path (mode $mode)"
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat >"$path"
  chmod "$mode" "$path"
  log "wrote $path"
}

# append_line <file> <line> : append line only if not already present.
append_line() {
  local file="$1" line="$2"
  if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then
    log "already present in $file: $line"
    return 0
  fi
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would append to $file: $line"
    return 0
  fi
  printf '%s\n' "$line" >>"$file"
  log "appended to $file: $line"
}

# in_group <user> <group>
in_group() {
  id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"
}
