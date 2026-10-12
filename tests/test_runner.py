from pathlib import Path
import logging
import tempfile

from debian_bootstrap.runner import Runner


def test_runner_dry_run_logs_not_execute(tmp_path):
    logger = logging.getLogger("test-runner")
    logger.handlers.clear()
    logger.setLevel(logging.INFO)
    script_dir = tmp_path / "scripts"
    script_dir.mkdir()
    (script_dir / "noop.sh").write_text("#!/usr/bin/env bash\ntouch /tmp/__should_not_exist__.marker\n")
    log_path = tmp_path / "log.txt"
    runner = Runner(
        logger=logger,
        scripts_dir=script_dir,
        dry_run=True,
        log_path=log_path,
    )
    runner.run("echo hello")
    runner.run_script(type("S", (), {"name": "noop", "script": "noop.sh", "description": "noop"})())
    assert log_path.exists()
    # Marker file must not be created in dry-run
    marker = Path("/tmp/__should_not_exist__.marker")
    if marker.exists():
        marker.unlink()
        raise AssertionError("dry-run should not execute commands")
