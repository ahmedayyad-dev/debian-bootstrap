from pathlib import Path
import tempfile
import textwrap

import pytest

from debian_bootstrap.config import ConfigError, load, validate, Config


def test_load_defaults():
    cfg = Config()
    validate(cfg)
    assert cfg.user.name == "ahmed"
    assert cfg.docker_user() == "ahmed"
    assert cfg.ufw.ports == [22, 80, 443]


def test_load_with_custom_values(tmp_path):
    toml = tmp_path / "cfg.toml"
    toml.write_text(
        textwrap.dedent(
            """
            [user]
            name = "deploy"
            ssh_public_key = "ssh-ed25519 AAAA test@example"

            [ssh]
            port = 2222

            [ufw]
            ports = [2222, 443]

            [docker]
            user = "deploy"

            [swap]
            size = "4G"
            swappiness = 20
            """
        )
    )
    cfg = load(toml)
    assert cfg.user.name == "deploy"
    assert cfg.ssh.port == 2222
    assert cfg.ufw.ports == [2222, 443]
    assert cfg.docker_user() == "deploy"
    assert cfg.swap.size == "4G"
    assert cfg.swap.swappiness == 20


def test_reject_root_user(tmp_path):
    toml = tmp_path / "bad.toml"
    toml.write_text(
        textwrap.dedent(
            """
            [user]
            name = "root"
            """
        )
    )
    with pytest.raises(ConfigError):
        load(toml)


def test_invalid_port(tmp_path):
    toml = tmp_path / "bad.toml"
    toml.write_text(
        textwrap.dedent(
            """
            [ssh]
            port = 70000
            """
        )
    )
    with pytest.raises(ConfigError):
        load(toml)


def test_empty_ufw_ports(tmp_path):
    toml = tmp_path / "bad.toml"
    toml.write_text(
        textwrap.dedent(
            """
            [ufw]
            ports = []
            """
        )
    )
    with pytest.raises(ConfigError):
        load(toml)


def test_swappiness_range(tmp_path):
    toml = tmp_path / "bad.toml"
    toml.write_text(
        textwrap.dedent(
            """
            [swap]
            swappiness = 150
            """
        )
    )
    with pytest.raises(ConfigError):
        load(toml)
