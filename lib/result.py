from dataclasses import dataclass
from typing import Literal, Union

from lib.logging import DiskoMessage, debug, print_msg


@dataclass
class DiskoSuccess:
    value: object
    context: None | str = None
    success: Literal[True] = True


@dataclass
class DiskoError:
    messages: list[DiskoMessage]
    context: str
    success: Literal[False] = False


DiskoResult = Union[DiskoSuccess, DiskoError]


def exit_on_error(result: DiskoResult) -> object:
    if isinstance(result, DiskoSuccess):
        if result.context is None:
            print_msg("BUG_SUCCESS_WITHOUT_CONTEXT", {"value": result.value})
        else:
            debug(f"Success in '{result.context}'")
            debug(f"Returned value: {result.value}")
        return result.value

    for message in result.messages:
        print_msg(message.code, message.details)

    exit(1)
