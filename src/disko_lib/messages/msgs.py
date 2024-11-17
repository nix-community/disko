import json
from pathlib import Path
from disko_lib.logging import ReadableMessage
from .colors import PLACEHOLDER, RESET, FLAG, COMMAND, INVALID, FILE, VALUE, EM, EM_WARN
from ..json_types import JsonDict

ERR_ARGUMENTS_HELP_TXT = f"Provide either {PLACEHOLDER}disko_file{RESET} as the second argument or \
{FLAG}--flake{RESET}/{FLAG}-f{RESET} {PLACEHOLDER}flake-uri{RESET}."


def err_command_failed(*, command: str, exit_code: int, stderr: str) -> ReadableMessage:
    return ReadableMessage(
        "error",
        f"""
            Command failed: {COMMAND}{command}{RESET}
            Exit code: {INVALID}{exit_code}{RESET}
            stderr: {stderr}
        """,
    )


def err_eval_config_failed(*, args: dict[str, str], stderr: str) -> ReadableMessage:
    return ReadableMessage(
        "error",
        f"""
            Failed to evaluate disko config with args {INVALID}{args}{RESET}!
            Stderr from {COMMAND}nix eval{RESET}:\n{stderr}
        """,
    )


def err_file_not_found(*, path: Path) -> ReadableMessage:
    return ReadableMessage("error", f"File not found: {FILE}{path}{RESET}")


def err_flake_uri_no_attr(*, flake_uri: str) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            f"Flake URI {INVALID}{flake_uri}{RESET} has no attribute.",
        ),
        ReadableMessage(
            "help",
            f"Append an attribute like {VALUE}#{PLACEHOLDER}foo{RESET} to the flake URI.",
        ),
    ]


def err_missing_arguments() -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            "Missing arguments!",
        ),
        ReadableMessage("help", ERR_ARGUMENTS_HELP_TXT),
    ]


def err_too_many_arguments() -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            "Too many arguments!",
        ),
        ReadableMessage("help", ERR_ARGUMENTS_HELP_TXT),
    ]


def err_missing_mode(*, valid_modes: list[str]) -> list[ReadableMessage]:
    modes_list = "\n".join([f"  - {VALUE}{m}{RESET}" for m in valid_modes])
    return [
        ReadableMessage("error", "Missing mode!"),
        ReadableMessage("help", "Allowed modes are:\n" + modes_list),
    ]


def err_unsupported_pttype(*, device: Path, pttype: str) -> ReadableMessage:
    return ReadableMessage(
        "error",
        f"Device {FILE}{device}{RESET} has unsupported partition type {INVALID}{pttype}{RESET}!",
    )


def warn_generate_partial_failure(
    *,
    partial_config: JsonDict,
    failed_devices: list[str],
    successful_devices: list[str],
) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "info",
            f"""
                Successfully generated config for {EM}some{RESET} devices.
                Errors are printed above. The generated partial config is:
                {json.dumps(partial_config, indent=2)}
                """,
        ),
        ReadableMessage(
            "warning",
            f"""
                Successfully generated config for {EM}some{RESET} devices, {EM_WARN}but not all{RESET}!
                Failed devices: {", ".join(f"{INVALID}{d}{RESET}" for d in failed_devices)}
                Successful devices: {", ".join(f"{VALUE}{d}{RESET}" for d in successful_devices)}
            """,
        ),
        ReadableMessage(
            "help",
            f"""
                The {INVALID}ERROR{RESET} messages are printed {EM}above the generated config{RESET}.
                Take a look at them and see if you can fix or safely ignore them.
                If you can't, but you need a solution now, you can try to use the generated config,
                but there is {EM_WARN}no guarantee{RESET} that it will work!
            """,
        ),
    ]
