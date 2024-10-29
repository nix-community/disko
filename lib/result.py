from dataclasses import dataclass
from typing import Any, Generic, Literal, TypeVar

from lib.logging import DiskoMessage, debug, print_msg, MessageCode

T = TypeVar("T", covariant=True)


@dataclass
class DiskoSuccess(Generic[T]):
    value: T
    context: None | str = None
    success: Literal[True] = True


@dataclass
class DiskoError:
    messages: list[DiskoMessage]
    context: str
    success: Literal[False] = False

    @classmethod
    def single_message(
        cls, code: MessageCode, details: dict[str, Any], context: str
    ) -> "DiskoError":
        return cls([DiskoMessage(code, details)], context)


DiskoResult = DiskoSuccess[T] | DiskoError


def exit_on_error(result: DiskoResult[T]) -> T:
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
