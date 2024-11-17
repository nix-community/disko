import json
from pathlib import Path
import readline
from typing import cast

from disko_lib.eval_config import eval_config_as_json, eval_and_validate_config
from disko_lib.messages.msgs import err_missing_arguments, err_too_many_arguments
from disko_lib.result import DiskoError, DiskoSuccess
from disko_lib.json_types import JsonDict

CURRENT_DIR = Path(__file__).parent
ROOT_DIR = CURRENT_DIR.parent.parent.parent
assert (ROOT_DIR / "flake.nix").exists()


def test_eval_config_missing_arguments() -> None:
    result = eval_config_as_json(disko_file=None, flake=None)
    assert isinstance(result, DiskoError)
    assert result.messages[0].is_message(err_missing_arguments)
    assert result.context == "validate args"


def test_eval_config_too_many_arguments() -> None:
    result = eval_config_as_json(disko_file="foo", flake="bar")
    assert isinstance(result, DiskoError)
    assert result.messages[0].is_message(err_too_many_arguments)
    assert result.context == "validate args"


def test_eval_config_disko_file() -> None:
    disko_file_path = ROOT_DIR / "example" / "simple-efi.nix"
    result = eval_config_as_json(disko_file=str(disko_file_path), flake=None)
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "file-simple-efi-eval-result.json") as f:
        expected_result = cast(JsonDict, json.load(f))
    assert result.value == expected_result


def test_eval_config_flake_testmachine() -> None:
    result = eval_config_as_json(disko_file=None, flake=f"{ROOT_DIR}#testmachine")
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "flake-testmachine-eval-result.json") as f:
        expected_result = cast(JsonDict, json.load(f))
    assert result.value == expected_result


def test_eval_and_validate_config_disko_file() -> None:
    disko_file_path = ROOT_DIR / "example" / "simple-efi.nix"
    result = eval_and_validate_config(disko_file=str(disko_file_path), flake=None)
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "file-simple-efi-validate-result.json") as f:
        expected_result = f.read()
    assert json.loads(result.value.model_dump_json()) == json.loads(expected_result)  # type: ignore[misc]


def test_eval_and_validate_flake_testmachine() -> None:
    result = eval_and_validate_config(disko_file=None, flake=f"{ROOT_DIR}#testmachine")
    assert isinstance(result, DiskoSuccess)
    with open(CURRENT_DIR / "flake-testmachine-validate-result.json") as f:
        expected_result = f.read()
    assert json.loads(result.value.model_dump_json()) == json.loads(expected_result)  # type: ignore[misc]
