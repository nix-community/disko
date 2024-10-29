# Logging functionality and global logging configuration
from dataclasses import dataclass, field
import logging
import re
from typing import Any, Literal, assert_never

from lib.ansi import Colors

logging.basicConfig(format="%(message)s", level=logging.INFO)
LOGGER = logging.getLogger("disko_logger")


# Color definitions. Note: Sort them alphabetically when adding new ones!
COMMAND = Colors.CYAN_ITALIC  # Commands that were run or can be run
FILE = Colors.BLUE  # File paths
FLAG = Colors.GREEN  # Command line flags (like --version or -f)
INVALID = Colors.RED  # Invalid values
PLACEHOLDER = Colors.MAGENTA_ITALIC  # Values that need to be replaced
VALUE = Colors.GREEN  # Values that are allowed

RESET = Colors.RESET  # Shortcut to reset the color


@dataclass
class ReadableMessage:
    type: Literal["bug", "error", "warning", "info", "help", "debug"]
    msg: str


# Codes for every single message that disko can print
# Note: Sort them alphabetically when adding new ones!
MessageCode = Literal[
    "BUG_SUCCESS_WITHOUT_CONTEXT",
    "ERR_COMMAND_FAILED",
    "ERR_EVAL_CONFIG_FAILED",
    "ERR_FILE_NOT_FOUND",
    "ERR_FLAKE_URI_NO_ATTR",
    "ERR_MISSING_ARGUMENTS",
    "ERR_MISSING_MODE",
    "ERR_TOO_MANY_ARGUMENTS",
]


@dataclass
class DiskoMessage:
    code: MessageCode
    details: dict[str, Any] = field(default_factory=dict)


ERR_ARGUMENTS_HELP_TXT = f"Provide either {PLACEHOLDER}disko_file{RESET} as the second argument or \
{FLAG}--flake{RESET}/{FLAG}-f{RESET} {PLACEHOLDER}flake-uri{RESET}."


def bug_help_message(error_code: MessageCode) -> ReadableMessage:
    return ReadableMessage(
        "help",
        f"""
            Please report this bug!
            First, check if has already been reported at
                https://github.com/nix-community/disko/issues?q=is%3Aissue+{error_code}
            If not, open a new issue at
                https://github.com/nix-community/disko/issues/new?title={error_code}
            and include the full logs printed above!
        """,
    )


def to_readable(message: DiskoMessage) -> list[ReadableMessage]:
    match message.code:
        case "BUG_SUCCESS_WITHOUT_CONTEXT":
            return [
                ReadableMessage(
                    "bug",
                    f"""
                        Success message without context!
                        Returned value:
                        {message.details['value']}
                    """,
                ),
                bug_help_message(message.code),
            ]
        case "ERR_COMMAND_FAILED":
            return [
                ReadableMessage(
                    "error",
                    f"""
                        Command failed: {COMMAND}{message.details['command']}{COMMAND}
                        Exit code: {INVALID}{message.details['exit_code']}{RESET}
                        stderr: {message.details['stderr']}
                    """,
                )
            ]
        case "ERR_EVAL_CONFIG_FAILED":
            return [
                ReadableMessage(
                    "error",
                    f"""
                        Failed to evaluate disko config with args {INVALID}{message.details['args']}{RESET}!
                        Stderr from {COMMAND}nix eval{RESET}:\n{message.details['stderr']}
                    """,
                )
            ]
        case "ERR_FILE_NOT_FOUND":
            return [
                ReadableMessage(
                    "error", f"File not found: {FILE}{message.details['path']}{RESET}"
                )
            ]
        case "ERR_FLAKE_URI_NO_ATTR":
            return [
                ReadableMessage(
                    "error",
                    f"Flake URI {INVALID}{message.details['flake_uri']}{RESET} has no attribute.",
                ),
                ReadableMessage(
                    "help",
                    f"Append an attribute like {VALUE}#{PLACEHOLDER}foo{RESET} to the flake URI.",
                ),
            ]
        case "ERR_MISSING_ARGUMENTS":
            return [
                ReadableMessage(
                    "error",
                    f"Missing arguments!",
                ),
                ReadableMessage("help", ERR_ARGUMENTS_HELP_TXT),
            ]
        case "ERR_TOO_MANY_ARGUMENTS":
            return [
                ReadableMessage(
                    "error",
                    f"Too many arguments!",
                ),
                ReadableMessage("help", ERR_ARGUMENTS_HELP_TXT),
            ]
        case "ERR_MISSING_MODE":
            modes_list = "\n".join(
                [f"  - {VALUE}{m}{RESET}" for m in message.details["valid_modes"]]
            )
            return [
                ReadableMessage("error", "Missing mode!"),
                ReadableMessage("help", "Allowed modes are:\n" + modes_list),
            ]

        # We could also remove these two lines, but assert_never emits a better error message
        case _ as c:
            assert_never(c)


# Dedent lines based on the indent of the first line until a non-indented line is hit.
# This will dedent the lines written in multiline f-strigns without breaking
# indentation for verbatim output that is inserted at the end
def dedent_start_lines(lines: list[str]) -> list[str]:
    spaces_prefix_match = re.match(r"^( *)", lines[0])
    # Regex will even match an empty string, match can't be none
    assert spaces_prefix_match is not None
    dedent_width = len(spaces_prefix_match.group(1))

    if dedent_width == 0:
        return lines

    match_indent_regex = re.compile(f"^ {{1,{dedent_width}}}")

    dedented_lines = []
    stop_dedenting = False
    for line in lines:
        if not line.startswith(" "):
            stop_dedenting = True

        if stop_dedenting:
            dedented_lines.append(line)
            continue

        dedented_line = re.sub(match_indent_regex, "", line)
        dedented_lines.append(dedented_line)

    return dedented_lines


def render_message(message: ReadableMessage) -> None:
    bg_color = {
        "bug": Colors.BG_RED,
        "error": Colors.BG_RED,
        "warning": Colors.BG_YELLOW,
        "info": Colors.BG_GREEN,
        "help": Colors.BG_LIGHT_MAGENTA,
        "debug": Colors.BG_LIGHT_CYAN,
    }[message.type]

    decor_color = {
        "bug": Colors.RED,
        "error": Colors.RED,
        "warning": Colors.YELLOW,
        "info": Colors.GREEN,
        "help": Colors.LIGHT_MAGENTA,
        "debug": Colors.LIGHT_CYAN,
    }[message.type]

    title_raw = {
        "bug": "BUG",
        "error": "ERROR",
        "warning": "WARNING",
        "info": "INFO",
        "help": "HELP",
        "debug": "DEBUG",
    }[message.type]

    log_msg = {
        "bug": LOGGER.error,
        "error": LOGGER.error,
        "warning": LOGGER.warning,
        "info": LOGGER.info,
        "help": LOGGER.info,
        "debug": LOGGER.debug,
    }[message.type]

    msg_lines = message.msg.strip("\n").splitlines()

    # "WARNING:" is 8 characters long, center in 10 for space on each side
    title = f"{bg_color}{title_raw + ":":^10}{RESET}"

    if len(msg_lines) == 1:
        log_msg(f"  {title} {msg_lines[0]}")
        return

    msg_lines = dedent_start_lines(msg_lines)

    log_msg(f"{decor_color}╭─{title} {msg_lines[0]}")

    for line in msg_lines[1:]:
        log_msg(f"{decor_color}│ {RESET} {line}")

    log_msg(f"{decor_color}╰───────────{RESET}")  # Exactly as long as the heading


def print_msg(code: MessageCode, details: dict[str, Any]) -> None:
    for msg in to_readable(DiskoMessage(code, details)):
        render_message(msg)


def debug(msg: str) -> None:
    # Check debug level immediately to avoid unnecessary formatting
    if LOGGER.isEnabledFor(logging.DEBUG):
        render_message(ReadableMessage("debug", str(msg)))


# In general, only debug messages should be logged directly, all other
# messages should be wrapped in a DiskoResult for easier testing
# Info is exposed only for testing during initial development of disko2
# TODO: Remove this function and use DiskoResult instead
def info(msg: str) -> None:
    render_message(ReadableMessage("info", str(msg)))
