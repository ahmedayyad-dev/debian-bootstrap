"""The ordered list of provisioning steps.

Python only decides *what* runs and how it is configured; the actual system
changes happen inside the idempotent bash scripts under ``scripts/``.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Mapping

from ..config import Config


@dataclass(frozen=True)
class Step:
    name: str
    script: str
    description: str
    env: Callable[[Config], Mapping[str, object]]
    enabled: Callable[[Config], bool] = field(default=lambda _config: True)


def _always(_config: Config) -> bool:
    return True


def _user_env(c: Config) -> dict[str, object]:
    return {
        "TARGET_USER": c.user.name,
        "TARGET_SHELL": c.user.shell,
        "TARGET_GROUPS": " ".join(c.user.groups),
        "SSH_PUBKEY": c.user.ssh_public_key,
        "SSH_PUBKEY_PATH": c.user.ssh_public_key_path,
    }


def _ssh_env(c: Config) -> dict[str, object]:
    return {
        "SSH_PORT": c.ssh.port,
        "SSH_PERMIT_ROOT_LOGIN": "yes" if c.ssh.permit_root_login else "no",
        "SSH_PASSWORD_AUTH": "yes" if c.ssh.password_authentication else "no",
    }


def _ufw_env(c: Config) -> dict[str, object]:
    return {"UFW_PORTS": " ".join(str(p) for p in c.ufw.ports)}


def _fail2ban_env(c: Config) -> dict[str, object]:
    return {
        "F2B_MAXRETRY": c.fail2ban.maxretry,
        "F2B_BANTIME": c.fail2ban.bantime,
    }


def _updates_env(c: Config) -> dict[str, object]:
    return {
        "UU_AUTO_REBOOT": "1" if c.updates.auto_reboot else "0",
        "UU_REBOOT_TIME": c.updates.auto_reboot_time,
    }


def _docker_env(c: Config) -> dict[str, object]:
    return {"DOCKER_USER": c.docker_user()}


def _swap_env(c: Config) -> dict[str, object]:
    return {"SWAP_SIZE": c.swap.size, "SWAP_SWAPPINESS": c.swap.swappiness}


def _time_env(c: Config) -> dict[str, object]:
    return {
        "TIMEZONE": c.time.timezone,
        "NTP_ENABLED": "1" if c.time.ntp else "0",
    }


def _systemd_env(_c: Config) -> dict[str, object]:
    return {}


STEPS: tuple[Step, ...] = (
    Step(
        "user",
        "01_create_user.sh",
        "Create non-root sudo user and install SSH key",
        _user_env,
    ),
    Step(
        "ssh",
        "02_harden_ssh.sh",
        "Harden sshd (disable root and password login)",
        _ssh_env,
    ),
    Step(
        "ufw",
        "03_configure_ufw.sh",
        "Configure UFW firewall (default deny, allow ports)",
        _ufw_env,
    ),
    Step(
        "fail2ban",
        "04_configure_fail2ban.sh",
        "Install and configure fail2ban for sshd",
        _fail2ban_env,
        enabled=lambda c: c.fail2ban.enabled,
    ),
    Step(
        "updates",
        "05_unattended_upgrades.sh",
        "Enable automatic security updates",
        _updates_env,
        enabled=lambda c: c.updates.unattended_upgrades,
    ),
    Step(
        "docker",
        "06_install_docker.sh",
        "Install Docker Engine and Compose plugin",
        _docker_env,
        enabled=lambda c: c.docker.install,
    ),
    Step(
        "swap",
        "07_configure_swap.sh",
        "Create swapfile and tune swappiness",
        _swap_env,
    ),
    Step(
        "time",
        "08_configure_time.sh",
        "Set timezone and enable NTP",
        _time_env,
    ),
    Step(
        "systemd",
        "09_install_systemd_templates.sh",
        "Install systemd unit templates",
        _systemd_env,
    ),
)
