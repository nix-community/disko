import json
from pathlib import Path
import re
from typing import Any

from lib.run_cmd import run
from lib.result import DiskoError, DiskoResult, DiskoSuccess

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


def eval_config(args: dict[str, str]) -> DiskoResult[dict[str, Any]]:
    args_as_json = json.dumps(args)

    result = run(
        NIX_EVAL_EXPR_CMD
        + [f"import {EVAL_CONFIG_NIX} (builtins.fromJSON ''{args_as_json}'')"]
    )

    if isinstance(result, DiskoError):
        return DiskoError.single_message(
            "ERR_EVAL_CONFIG_FAILED",
            {"args": args, "stderr": result.messages[0].details["stderr"]},
            "evaluate disko configuration",
        )
        return result

    # We trust the output of `nix eval` to be valid JSON
    return DiskoSuccess(json.loads(result.value), "evaluate disko config")


def eval_disko_file(config_file: Path) -> DiskoResult[dict[str, Any]]:
    abs_path = config_file.absolute()

    if not abs_path.exists():
        return DiskoError.single_message(
            "ERR_FILE_NOT_FOUND",
            {"path": abs_path},
            "evaluate disko_file",
        )

    return eval_config({"diskoFile": str(abs_path)})


def eval_flake(flake_uri: str) -> DiskoResult[dict[str, Any]]:
    # arg parser should not allow empty strings
    assert len(flake_uri) > 0

    flake_match = re.match(r"^([^#]+)(?:#(.*))?$", flake_uri)

    # Match can't be none if we receive at least one character
    assert flake_match is not None

    flake = flake_match.group(1)
    flake_attr = flake_match.group(2)

    if not flake_attr:
        return DiskoError.single_message(
            "ERR_FLAKE_URI_NO_ATTR", {"flake_uri": flake_uri}, "evaluate flake"
        )

    flake_path = Path(flake)
    if flake_path.exists():
        flake = str(flake_path.absolute())

    return eval_config({"flake": flake, "flakeAttr": flake_attr})
