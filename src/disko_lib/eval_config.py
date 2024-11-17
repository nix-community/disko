import json
from pathlib import Path
import re
from typing import Any, cast

from pydantic import ValidationError

from disko_lib.config_type import DiskoConfig
from disko_lib.messages.bugs import bug_validate_config_failed

from .json_types import JsonDict

from disko_lib.messages.msgs import (
    err_eval_config_failed,
    err_file_not_found,
    err_flake_uri_no_attr,
    err_missing_arguments,
    err_too_many_arguments,
)

from .run_cmd import run
from .result import DiskoError, DiskoResult, DiskoSuccess

NIX_BASE_CMD = [
    "nix",
    "--extra-experimental-features",
    "nix-command",
    "--extra-experimental-features",
    "flakes",
]

NIX_EVAL_EXPR_CMD = NIX_BASE_CMD + ["eval", "--impure", "--json", "--expr"]

EVAL_CONFIG_NIX = Path(__file__).absolute().parent / "eval-config.nix"
assert (
    EVAL_CONFIG_NIX.exists()
), f"Can't find `eval-config.nix`, expected it next to {__file__}"


def _eval_config(args: dict[str, str]) -> DiskoResult[JsonDict]:
    args_as_json = json.dumps(args)

    result = run(
        NIX_EVAL_EXPR_CMD
        + [f"import {EVAL_CONFIG_NIX} (builtins.fromJSON ''{args_as_json}'')"]
    )

    if isinstance(result, DiskoError):
        return DiskoError.single_message(
            err_eval_config_failed,
            "evaluate disko configuration",
            args=args,
            stderr=cast(str, result.messages[0].details["stderr"]),
        )

    # We trust the output of `nix eval` to be valid JSON
    return DiskoSuccess(
        cast(JsonDict, json.loads(result.value)), "evaluate disko config"
    )


def _eval_disko_file(config_file: Path) -> DiskoResult[JsonDict]:
    abs_path = config_file.absolute()

    if not abs_path.exists():
        return DiskoError.single_message(
            err_file_not_found,
            "evaluate disko_file",
            path=abs_path,
        )

    return _eval_config({"diskoFile": str(abs_path)})


def _eval_flake(flake_uri: str) -> DiskoResult[JsonDict]:
    # arg parser should not allow empty strings
    assert len(flake_uri) > 0

    flake_match = re.match(r"^([^#]+)(?:#(.*))?$", flake_uri)

    # Match can't be none if we receive at least one character
    assert flake_match is not None
    flake = cast(str, flake_match.group(1))
    flake_attr = cast(str, flake_match.group(2))

    if not flake_attr:
        return DiskoError.single_message(
            err_flake_uri_no_attr, "evaluate flake", flake_uri=flake_uri
        )

    flake_path = Path(flake)
    if flake_path.exists():
        flake = str(flake_path.absolute())

    return _eval_config({"flake": flake, "flakeAttr": flake_attr})


def eval_config_as_json(
    *, disko_file: str | None, flake: str | None
) -> DiskoResult[JsonDict]:
    # match would be nicer, but mypy doesn't understand type narrowing in tuples
    if not disko_file and not flake:
        return DiskoError.single_message(err_missing_arguments, "validate args")
    if not disko_file and flake:
        return _eval_flake(flake)
    if disko_file and not flake:
        return _eval_disko_file(Path(disko_file))

    return DiskoError.single_message(err_too_many_arguments, "validate args")


def eval_and_validate_config(
    *, disko_file: str | None, flake: str | None
) -> DiskoResult[DiskoConfig]:
    json_config = eval_config_as_json(disko_file=disko_file, flake=flake)

    if isinstance(json_config, DiskoError):
        return json_config

    try:
        result = DiskoConfig(**cast(dict[str, Any], json_config.value))  # type: ignore[misc]
    except ValidationError as e:
        return DiskoError.single_message(
            bug_validate_config_failed,
            "validate disko config",
            error=e,
            config=json_config.value,
        )

    return DiskoSuccess(result, "validate disko config")
