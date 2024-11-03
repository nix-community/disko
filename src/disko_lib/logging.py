# Logging functionality and global logging configuration
from dataclasses import dataclass
import logging
import re
from typing import (
    Any,
    Callable,
    Generic,
    Literal,
    ParamSpec,
    TypeAlias,
)

from .ansi import Colors
from .messages.colors import RESET

logging.basicConfig(format="%(message)s", level=logging.INFO)
LOGGER = logging.getLogger("disko_logger")


@dataclass
class ReadableMessage:
    type: Literal["bug", "error", "warning", "info", "help", "debug"]
    msg: str


P = ParamSpec("P")

MessageFactory: TypeAlias = Callable[P, ReadableMessage | list[ReadableMessage]]


@dataclass
class DiskoMessage(Generic[P]):
    factory: MessageFactory[P]
    # Can't infer a TypedDict from a ParamSpec yet (mypy 1.10.1, python 3.12.5)
    # This is only safe to use because the type of __init__ ensures that the
    # keys in details are the same as the keys in the factory kwargs
    details: dict[str, Any]

    def __init__(self, factory: MessageFactory[P], **details: P.kwargs) -> None:
        self.factory = factory
        self.details = details

    def to_readable(self) -> list[ReadableMessage]:
        result = self.factory(**self.details)
        if isinstance(result, list):
            return result
        return [result]

    def print(self) -> None:
        for msg in self.to_readable():
            render_message(msg)


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

    match_indent_regex = re.compile(f"^ {{{dedent_width}}}")

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

    msg_lines = message.msg.strip("\n").rstrip(" \n").splitlines()

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
