#!/usr/bin/env bash
#
# Install Docker Engine and the Compose v2 plugin from the official repo.
#
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

require_root

: "${DOCKER_USER:=}"

if have_cmd docker; then
  log "docker already installed: $(docker --version 2>/dev/null || echo unknown)"
else
  apt_update
  apt_install ca-certificates curl gnupg

  run install -m 0755 -d /etc/apt/keyrings

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would add Docker GPG key and apt repository"
  else
    if [[ ! -s /etc/apt/keyrings/docker.gpg ]]; then
      curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      log "installed Docker GPG key"
    else
      log "Docker GPG key already present"
    fi
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  arch="$(dpkg --print-architecture)"
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable"

  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] would write /etc/apt/sources.list.d/docker.list"
  else
    printf '%s\n' "${repo_line}" >/etc/apt/sources.list.d/docker.list
    log "wrote /etc/apt/sources.list.d/docker.list"
  fi

  APT_UPDATED=0
  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  run systemctl enable --now docker
  log "Docker Engine and Compose plugin installed"
fi

if [[ -n "${DOCKER_USER}" ]] && id "${DOCKER_USER}" >/dev/null 2>&1; then
  if in_group "${DOCKER_USER}" docker; then
    log "user '${DOCKER_USER}' already in group 'docker'"
  else
    run usermod -aG docker "${DOCKER_USER}"
    log "added '${DOCKER_USER}' to group 'docker'"
  fi
elif [[ -n "${DOCKER_USER}" ]]; then
  warn "user '${DOCKER_USER}' does not exist; not adding to docker group"
fi
