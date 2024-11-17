#!/usr/bin/env python3

import argparse
import json
from typing import Any, Literal, cast

from disko.mode_dev import run_dev
from disko.mode_generate import run_generate
from disko_lib.config_type import DiskoConfig
from disko_lib.eval_config import eval_and_validate_config
from disko_lib.logging import LOGGER, debug, info
from disko_lib.messages.msgs import err_missing_mode
from disko_lib.result import DiskoError, DiskoResult, exit_on_error
from disko_lib.json_types import JsonDict

Mode = Literal[
    "destroy",
    "format",
    "mount",
    "destroy,format,mount",
    "format,mount",
    "generate",
    "dev",
]


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
    *, mode: str, disko_file: str | None, flake: str | None, **_kwargs: dict[str, Any]
) -> DiskoResult[DiskoConfig]:
    return eval_and_validate_config(disko_file=disko_file, flake=flake)


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
