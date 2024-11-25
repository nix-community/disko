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


def err_disk_type_changed_no_destroy(
    *, disk: str, device: str, old_type: str, new_type: str
) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            f"""
                Disk {VALUE}{disk}{RESET} ({FILE}{device}{RESET}) changed type from {INVALID}{old_type}{RESET} to {INVALID}{new_type}{RESET}.
                Need to destroy and recreate the disk, but the current mode does not allow it!
            """,
        ),
        ReadableMessage(
            "help",
            f"""
                Run `{COMMAND}disko{RESET} {VALUE}destroy,format,mount{RESET}` to allow destructive changes,
                or change {VALUE}{disk}{RESET}'s type back to {INVALID}{old_type}{RESET} to keep the data.
            """,
        ),
    ]


def err_disk_not_found(*, disk: str, device: str) -> ReadableMessage:
    return ReadableMessage(
        "error",
        f"Device path {FILE}{device}{RESET} (for disk {VALUE}{disk}{RESET}) was not found!",
    )


def err_duplicated_disk_devices(
    *, devices: list[str], duplicates: set[str]
) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            f"""
            Your config sets the same device path for multiple disks!
            Devices: {", ".join(f"{VALUE}{d}{RESET}" for d in sorted(devices))}
        """,
        ),
        ReadableMessage(
            "help",
            f"""The duplicates are:
            {", ".join(f"{INVALID}{d}{RESET}" for d in duplicates)}
        """,
        ),
    ]


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


def err_filesystem_changed_no_destroy(
    *, device: str, old_format: str, new_format: str
) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "error",
            f"""
                Filesystem on device {FILE}{device}{RESET} changed from {INVALID}{old_format}{RESET} to {INVALID}{new_format}{RESET}.
                Need to destroy and recreate the filesystem, but the current mode does not allow it!
            """,
        ),
        ReadableMessage(
            "help",
            f"""
                Run `{COMMAND}disko{RESET} {VALUE}destroy,format,mount{RESET}` to allow destructive changes,
                or change the filesystem back to {INVALID}{old_format}{RESET} to keep the data.
            """,
        ),
    ]


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
    kind: str,
    failed: list[str],
    successful: list[str],
) -> ReadableMessage:
    partially_successful = [x for x in successful if x in failed]
    failed = [x for x in failed if x not in partially_successful]
    successful = [x for x in successful if x not in partially_successful]
    return ReadableMessage(
        "warning",
        f"""
                Successfully generated config for {EM}some{RESET} {kind}s of your setup, {EM_WARN}but not all{RESET}!
                Failed {kind}s: {", ".join(f"{INVALID}{d}{RESET}" for d in failed)}
                Successful {kind}s: {", ".join(f"{VALUE}{d}{RESET}" for d in successful)}
                Partially successful {kind}s: {", ".join(f"{EM_WARN}{d}{RESET}" for d in partially_successful)}
            """,
    )


def help_generate_partial_failure(
    *,
    partial_config: JsonDict,
    failed: list[str],
    successful: list[str],
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
        warn_generate_partial_failure(
            kind="section",
            failed=failed,
            successful=successful,
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
