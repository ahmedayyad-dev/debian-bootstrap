"""Configuration loading and validation for debian-bootstrap."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field, fields
from pathlib import Path
from typing import Any


class ConfigError(ValueError):
    """Raised when the configuration file is missing keys or invalid values."""


@dataclass
class UserSection:
    name: str = "ahmed"
    shell: str = "/bin/bash"
    groups: list[str] = field(default_factory=lambda: ["sudo"])
    ssh_public_key: str = ""
    ssh_public_key_path: str = ""


@dataclass
class SshSection:
    port: int = 22
    permit_root_login: bool = False
    password_authentication: bool = False


@dataclass
class UfwSection:
    ports: list[int] = field(default_factory=lambda: [22, 80, 443])


@dataclass
class Fail2banSection:
    enabled: bool = True
    maxretry: int = 5
    bantime: str = "1h"


@dataclass
class UpdatesSection:
    unattended_upgrades: bool = True
    auto_reboot: bool = False
    auto_reboot_time: str = "03:30"


@dataclass
class DockerSection:
    install: bool = True
    user: str = ""


@dataclass
class SwapSection:
    size: str = "2G"
    swappiness: int = 10


@dataclass
class TimeSection:
    timezone: str = "UTC"
    ntp: bool = True


@dataclass
class Config:
    user: UserSection = field(default_factory=UserSection)
    ssh: SshSection = field(default_factory=SshSection)
    ufw: UfwSection = field(default_factory=UfwSection)
    fail2ban: Fail2banSection = field(default_factory=Fail2banSection)
    updates: UpdatesSection = field(default_factory=UpdatesSection)
    docker: DockerSection = field(default_factory=DockerSection)
    swap: SwapSection = field(default_factory=SwapSection)
    time: TimeSection = field(default_factory=TimeSection)
    path: Path | None = None

    def docker_user(self) -> str:
        """User added to the docker group (falls back to the main user)."""
        return self.docker.user or self.user.name


_SECTIONS = {
    "user": UserSection,
    "ssh": SshSection,
    "ufw": UfwSection,
    "fail2ban": Fail2banSection,
    "updates": UpdatesSection,
    "docker": DockerSection,
    "swap": SwapSection,
    "time": TimeSection,
}


def _build(section_name: str, data: Any) -> Any:
    cls = _SECTIONS[section_name]
    if not isinstance(data, dict):
        raise ConfigError(f"[{section_name}] must be a table")
    valid = {f.name for f in fields(cls)}
    unknown = set(data) - valid
    if unknown:
        raise ConfigError(
            f"[{section_name}] unknown key(s): {', '.join(sorted(unknown))}"
        )
    try:
        return cls(**data)
    except (TypeError, ValueError) as exc:
        raise ConfigError(f"[{section_name}]: {exc}") from exc


def load(path: str | Path) -> Config:
    """Load and validate a TOML configuration file."""
    path = Path(path)
    with path.open("rb") as fh:
        raw = tomllib.load(fh)

    unknown = set(raw) - set(_SECTIONS)
    if unknown:
        raise ConfigError(f"unknown section(s): {', '.join(sorted(unknown))}")

    sections = {name: _build(name, raw.get(name, {})) for name in _SECTIONS}
    config = Config(path=path, **sections)
    validate(config)
    return config


def _check_port(value: Any, where: str) -> None:
    if not isinstance(value, int) or isinstance(value, bool) or not (1 <= value <= 65535):
        raise ConfigError(f"{where} must be an integer between 1 and 65535")


def validate(config: Config) -> None:
    """Validate cross-field and range constraints."""
    if not config.user.name or config.user.name.strip() == "":
        raise ConfigError("[user] name must not be empty")
    if config.user.name == "root":
        raise ConfigError(
            "[user] name must not be 'root'; this tool creates a non-root sudo user"
        )
    if any(g == "root" for g in config.user.groups):
        raise ConfigError("[user] groups must not contain 'root'")

    _check_port(config.ssh.port, "[ssh] port")
    if not config.ufw.ports:
        raise ConfigError("[ufw] ports must not be empty")
    for port in config.ufw.ports:
        _check_port(port, "[ufw] ports")

    if not isinstance(config.fail2ban.maxretry, int) or config.fail2ban.maxretry < 1:
        raise ConfigError("[fail2ban] maxretry must be a positive integer")

    if not (0 <= config.swap.swappiness <= 100):
        raise ConfigError("[swap] swappiness must be between 0 and 100")

    if not config.time.timezone:
        raise ConfigError("[time] timezone must not be empty")
