import argparse
import json
from typing import Any, cast

from disko_lib.ansi import Colors
from disko_lib.eval_config import eval_and_validate_config, eval_config_as_json
from disko_lib.messages.msgs import err_missing_mode
from disko_lib.result import DiskoError, DiskoSuccess, DiskoResult
from disko_lib.types.device import run_lsblk


def run_dev_lsblk() -> DiskoResult[None]:
    output = run_lsblk()
    if isinstance(output, DiskoError):
        return output

    print(output.value)
    return DiskoSuccess(None, "run disko dev lsblk")


def run_dev_ansi() -> DiskoResult[None]:
    import inspect

    for name, value in inspect.getmembers(Colors):
        if value != "_" and not name.startswith("_") and name != "RESET":  # type: ignore[misc]
            print("{:>30} {}".format(name, value + name + Colors.RESET))  # type: ignore[misc]

    return DiskoSuccess(None, "run disko dev ansi")


def run_dev_eval(
    *, disko_file: str | None, flake: str | None, **_: Any
) -> DiskoResult[None]:
    result = eval_config_as_json(disko_file=disko_file, flake=flake)

    if isinstance(result, DiskoError):
        return result

    print(json.dumps(result.value, indent=2))
    return DiskoSuccess(None, "run disko dev eval")


def run_dev_validate(
    *, disko_file: str | None, flake: str | None, **_: Any
) -> DiskoResult[None]:
    result = eval_and_validate_config(disko_file=disko_file, flake=flake)

    if isinstance(result, DiskoError):
        return result

    print(result.value.model_dump_json(indent=2))
    return DiskoSuccess(None, "run disko dev validate")


def run_dev(args: argparse.Namespace) -> DiskoResult[None]:
    match cast(str | None, args.dev_command):
        case "lsblk":
            return run_dev_lsblk()
        case "ansi":
            return run_dev_ansi()
        case "eval":
            return run_dev_eval(**vars(args))  # type: ignore[misc]
        case "validate":
            return run_dev_validate(**vars(args))  # type: ignore[misc]
        case _:
            return DiskoError.single_message(
                err_missing_mode,
                "select mode",
                valid_modes=["lsblk", "ansi", "eval", "validate"],
            )
