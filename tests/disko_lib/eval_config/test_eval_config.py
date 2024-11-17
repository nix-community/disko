import json
from pathlib import Path
from typing import cast

from disko_lib.eval_config import eval_config
from disko_lib.messages.msgs import err_missing_arguments, err_too_many_arguments
from disko_lib.result import DiskoError, DiskoSuccess
from disko_lib.json_types import JsonDict

CURRENT_DIR = Path(__file__).parent
ROOT_DIR = CURRENT_DIR.parent.parent.parent
assert (ROOT_DIR / "flake.nix").exists()


def test_eval_config_missing_arguments() -> None:
    result = eval_config(disko_file=None, flake=None)
    assert isinstance(result, DiskoError)
    assert result.messages[0].is_message(err_missing_arguments)
    assert result.context == "validate args"


def test_eval_config_too_many_arguments() -> None:
    result = eval_config(disko_file="foo", flake="bar")
    assert isinstance(result, DiskoError)
    assert result.messages[0].is_message(err_too_many_arguments)
    assert result.context == "validate args"


def test_eval_config_disk_file() -> None:
    disko_file_path = ROOT_DIR / "example" / "simple-efi.nix"
    result = eval_config(disko_file=str(disko_file_path), flake=None)
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "file-simple-efi-result.json") as f:
        expected_result = cast(JsonDict, json.load(f))
    assert result.value == expected_result


def test_eval_config_flake_testmachine() -> None:
    result = eval_config(disko_file=None, flake=f"{ROOT_DIR}#testmachine")
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "flake-testmachine-result.json") as f:
        expected_result = cast(JsonDict, json.load(f))
    assert result.value == expected_result
