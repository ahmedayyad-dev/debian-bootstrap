from debian_bootstrap import cli


def test_repo_root_contains_scripts():
    root = cli.repo_root()
    assert (root / "scripts" / "lib" / "common.sh").is_file()
    assert (root / "bootstrap.sh").is_file()


def test_list_steps_returns_zero():
    assert cli.main(["--list"]) == 0
