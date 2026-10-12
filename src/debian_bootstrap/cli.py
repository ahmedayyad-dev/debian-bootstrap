"""Command line interface for debian-bootstrap."""

from __future__ import annotations

import argparse
import logging
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from . import __version__
from .config import Config, ConfigError
from .config import load as load_config
from .modules.registry import STEPS, Step
from .runner import Runner


def repo_root() -> Path:
    """Locate the repository root containing scripts/ and templates/."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "scripts" / "lib" / "common.sh").is_file():
            return parent
    return here.parents[2]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="debian-bootstrap",
        description="Prepare and harden a fresh Debian 12 server (idempotent).",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config/bootstrap.toml"),
        help="path to the TOML config (default: config/bootstrap.toml)",
    )
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        metavar="STEP",
        help="run only the given step(s); may be repeated",
    )
    parser.add_argument(
        "--skip",
        action="append",
        default=[],
        metavar="STEP",
        help="skip the given step(s); may be repeated",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print actions without changing the system",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="list available steps and exit",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="enable debug logging",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def setup_logging(log_path: Path | None, verbose: bool) -> logging.Logger:
    logger = logging.getLogger("debian-bootstrap")
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)
    logger.handlers.clear()
    logger.propagate = False

    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", "%Y-%m-%d %H:%M:%S")

    console = logging.StreamHandler()
    console.setFormatter(fmt)
    logger.addHandler(console)

    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_path)
        file_handler.setFormatter(fmt)
        logger.addHandler(file_handler)

    return logger


def select_steps(
    steps: tuple[Step, ...], only: list[str], skip: list[str], config: Config
) -> list[Step]:
    known = {s.name for s in steps}
    unknown = (set(only) | set(skip)) - known
    if unknown:
        raise SystemExit(
            f"unknown step(s): {', '.join(sorted(unknown))}. "
            f"Known: {', '.join(sorted(known))}"
        )
    selected: list[Step] = []
    for step in steps:
        if only and step.name not in only:
            continue
        if step.name in skip:
            continue
        if not step.enabled(config):
            continue
        selected.append(step)
    return selected


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.list:
        width = max(len(s.name) for s in STEPS)
        for step in STEPS:
            print(f"{step.name:<{width}}  {step.description}")
        return 0

    try:
        config = load_config(args.config)
    except FileNotFoundError:
        print(
            f"config not found: {args.config}\n"
            f"copy config/bootstrap.example.toml to {args.config} and edit it",
            file=sys.stderr,
        )
        return 2
    except ConfigError as exc:
        print(f"invalid config: {exc}", file=sys.stderr)
        return 2

    root = repo_root()
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    log_path = root / "logs" / f"bootstrap-{timestamp}.log"
    logger = setup_logging(log_path, args.verbose)

    logger.info("debian-bootstrap %s", __version__)
    logger.info("config: %s", config.path)
    logger.info("log: %s", log_path)
    if args.dry_run:
        logger.info("DRY RUN: no changes will be made")

    try:
        selected = select_steps(STEPS, args.only, args.skip, config)
    except SystemExit as exc:
        logger.error("%s", exc)
        return 2

    if not selected:
        logger.warning("no steps selected; nothing to do")
        return 0

    logger.info("steps: %s", ", ".join(s.name for s in selected))

    runner = Runner(
        logger=logger,
        scripts_dir=root / "scripts",
        dry_run=args.dry_run,
        log_path=log_path,
        templates_dir=root / "templates" / "systemd",
    )

    failed: list[str] = []
    for step in selected:
        try:
            runner.run_script(step, step.env(config))
        except subprocess.CalledProcessError as exc:
            logger.error("step '%s' failed with exit code %s", step.name, exc.returncode)
            failed.append(step.name)
            break
        except FileNotFoundError as exc:
            logger.error("%s", exc)
            failed.append(step.name)
            break

    if failed:
        logger.error("bootstrap failed at step: %s", ", ".join(failed))
        return 1

    logger.info("bootstrap completed successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
