#!/usr/bin/env python3

import argparse
import dataclasses
import json
from typing import Any, Literal, cast

from disko.mode_dev import run_dev
from disko.mode_generate import run_generate
from disko_lib.action import Action
from disko_lib.config_type import DiskoConfig
from disko_lib.eval_config import (
    eval_config_dict_as_json,
    eval_config_file_as_json,
    validate_config,
)
from disko_lib.generate_config import generate_config
from disko_lib.generate_plan import generate_plan
from disko_lib.logging import LOGGER, debug, info
from disko_lib.messages.msgs import err_missing_mode
from disko_lib.result import (
    DiskoError,
    DiskoPartialSuccess,
    DiskoResult,
    DiskoSuccess,
    exit_on_error,
)
from disko_lib.json_types import JsonDict

Mode = (
    Action
    | Literal[
        "destroy,format,mount",
        "format,mount",
        "generate",
        "dev",
    ]
)

MODE_TO_ACTIONS: dict[Mode, set[Action]] = {
    "destroy": {"destroy"},
    "format": {"format"},
    "mount": {"mount"},
    "destroy,format,mount": {"destroy", "format", "mount"},
    "format,mount": {"format", "mount"},
}


# Modes to apply an existing configuration
APPLY_MODES: list[Mode] = [
    "destroy",
    "format",
    "mount",
    "destroy,format,mount",
    "format,mount",
]
ALL_MODES: list[Mode] = APPLY_MODES + ["generate", "dev"]

MODE_DESCRIPTION: dict[Mode, str] = {
    "destroy": "Destroy the partition tables on the specified disks",
    "format": "Change formatting and filesystems on the specified disks",
    "mount": "Mount the specified disks",
    "destroy,format,mount": "Run destroy, format and mount in sequence",
    "format,mount": "Run format and mount in sequence",
    "generate": "Generate a disko configuration file from the system's current state",
    "dev": "Print information useful for developers",
}


def run_apply(
    *,
    mode: Mode,
    disko_file: str | None,
    flake: str | None,
    dry_run: bool,
    **_kwargs: dict[str, Any],
) -> DiskoResult[JsonDict]:
    assert mode in APPLY_MODES

    target_config_json = eval_config_file_as_json(disko_file=disko_file, flake=flake)
    if isinstance(target_config_json, DiskoError):
        return target_config_json

    target_config = validate_config(target_config_json.value)
    if isinstance(target_config, DiskoError):
        return target_config.with_context("validate evaluated config")

    current_status_dict = generate_config()
    if isinstance(current_status_dict, DiskoError) and not isinstance(
        current_status_dict, DiskoPartialSuccess
    ):
        return current_status_dict.with_context("generate current status")

    current_status_evaluated = eval_config_dict_as_json(current_status_dict.value)
    if isinstance(current_status_evaluated, DiskoError):
        return current_status_evaluated.with_context("eval current status")

    current_status = validate_config(current_status_evaluated.value)
    if isinstance(current_status, DiskoError):
        return current_status.with_context("validate current status")

    actions = MODE_TO_ACTIONS[mode]

    plan = generate_plan(actions, current_status.value, target_config.value)
    if isinstance(plan, DiskoError):
        return plan

    plan_as_dict: JsonDict = dataclasses.asdict(plan.value)
    steps = {"steps": plan_as_dict.get("steps", [])}

    if dry_run:
        return DiskoSuccess(steps, "generate plan")

    info("Plan execution is not implemented yet!")

    return DiskoSuccess(steps, "generate plan")


def run(
    args: argparse.Namespace,
) -> DiskoResult[None | JsonDict | DiskoConfig]:
    if cast(bool, args.verbose):
        LOGGER.setLevel("DEBUG")
        debug("Enabled debug logging.")

    match cast(Mode | None, args.mode):
        case None:
            return DiskoError.single_message(
                err_missing_mode, "select mode", valid_modes=[str(m) for m in ALL_MODES]
            )
        case "generate":
            return run_generate()
        case "dev":
            return run_dev(args)
        case _:
            return run_apply(**vars(args))  # type: ignore[misc]


def parse_args() -> argparse.Namespace:
    root_parser = argparse.ArgumentParser(
        prog="disko2",
        description="Automated disk partitioning and formatting tool for NixOS",
    )

    root_parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        default=False,
        help="Print more detailed output, helpful for debugging",
    )

    mode_parsers = root_parser.add_subparsers(dest="mode")

    def create_apply_parser(mode: Mode) -> argparse.ArgumentParser:
        parser = mode_parsers.add_parser(
            mode,
            help=MODE_DESCRIPTION[mode],
        )
        return parser

    def add_common_apply_args(parser: argparse.ArgumentParser) -> None:
        parser.add_argument(
            "disko_file",
            nargs="?",
            default=None,
            help="Path to the disko configuration file",
        )
        parser.add_argument(
            "--flake",
            "-f",
            help="Flake to fetch the disko configuration from",
        )
        parser.add_argument(
            "--dry-run",
            "-n",
            action="store_true",
            default=False,
            help="Print the plan without executing it",
        )

    # Commands to apply an existing configuration
    apply_parsers = [create_apply_parser(mode) for mode in APPLY_MODES]
    for parser in apply_parsers:
        add_common_apply_args(parser)

    # Other commands
    _generate_parser = mode_parsers.add_parser(
        "generate",
        help=MODE_DESCRIPTION["generate"],
    )

    # Commands for developers
    dev_parsers = mode_parsers.add_parser(
        "dev",
        help=MODE_DESCRIPTION["dev"],
    ).add_subparsers(dest="dev_command")
    dev_parsers.add_parser("lsblk", help="List block devices the way disko sees them")
    dev_parsers.add_parser("ansi", help="Print defined ansi color codes")

    dev_eval_parser = dev_parsers.add_parser(
        "eval", help="Evaluate a disko configuration and print the result as JSON"
    )
    add_common_apply_args(dev_eval_parser)
    dev_validate_parser = dev_parsers.add_parser(
        "validate",
        help="Validate a disko configuration file or flake",
    )
    add_common_apply_args(dev_validate_parser)

    return root_parser.parse_args()


def main() -> None:
    args = parse_args()
    result = run(args)
    output = exit_on_error(result)
    if output:
        info("Output:\n" + json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
