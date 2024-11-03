import argparse
import json
from logging import info
from typing import Any, assert_never

from disko_lib.ansi import Colors
from disko_lib.eval_config import eval_config
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
        if value != "_" and not name.startswith("_") and name != "RESET":
            print("{:>30} {}".format(name, value + name + Colors.RESET))

    return DiskoSuccess(None, "run disko dev ansi")


def run_dev_eval(
    *, disko_file: str | None, flake: str | None, **_: Any
) -> DiskoResult[None]:
    result = eval_config(disko_file=disko_file, flake=flake)

    if isinstance(result, DiskoError):
        return result

    print(json.dumps(result.value, indent=2))
    return DiskoSuccess(None, "run disko dev eval")


def run_dev(args: argparse.Namespace) -> DiskoResult[None]:
    match args.dev_command:
        case "lsblk":
            return run_dev_lsblk()
        case "ansi":
            return run_dev_ansi()
        case "eval":
            return run_dev_eval(**vars(args))
        case _:
            assert_never(args.dev_command)
