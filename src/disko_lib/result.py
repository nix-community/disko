from dataclasses import dataclass
from typing import Any, Generic, ParamSpec, TypeVar, cast

from disko_lib.messages.bugs import bug_success_without_context

from .logging import (
    DiskoMessage,
    ReadableMessage,
    debug,
    MessageFactory,
    render_message,
)

T = TypeVar("T", covariant=True)
S = TypeVar("S")
P = ParamSpec("P")


@dataclass
class DiskoSuccess(Generic[T]):
    value: T
    context: None | str = None


@dataclass
class DiskoError:
    messages: list[DiskoMessage[object]]
    context: str

    def __len__(self) -> int:
        return len(self.messages)

    @classmethod
    def single_message(
        cls, factory: MessageFactory[P], context: str, *_: P.args, **details: P.kwargs
    ) -> "DiskoError":
        _factory = cast(MessageFactory[object], factory)
        return cls([DiskoMessage(_factory, **details)], context)

    def find_message(
        self, message_factory: MessageFactory[P]
    ) -> None | DiskoMessage[P]:
        for message in self.messages:
            if message.factory == message_factory:
                return cast(DiskoMessage[P], message)
        return None

    def append(self, message: DiskoMessage[Any]) -> None:
        self.messages.append(message)  # type: ignore[misc]

    def extend(self, other_error: "DiskoError") -> None:
        self.messages.extend(other_error.messages)

    def with_context(self, context: str) -> "DiskoError":
        return DiskoError(self.messages, context)

    def to_partial_success(self, value: S) -> "DiskoPartialSuccess[S]":
        return DiskoPartialSuccess(self.messages, self.context, value)


@dataclass
class DiskoPartialSuccess(Generic[T], DiskoError):
    value: T


DiskoResult = DiskoSuccess[T] | DiskoPartialSuccess[T] | DiskoError  # type: ignore[misc, unused-ignore]


def exit_on_error(result: DiskoResult[T]) -> T:
    if isinstance(result, DiskoSuccess):
        if result.context is None:
            DiskoMessage(bug_success_without_context, value=result.value).print()
        else:
            debug(f"Success in '{result.context}'")
            debug(f"Returned value: {result.value}")
        return result.value

    render_message(ReadableMessage("error", f"Failed to {result.context}!"))

    for message in result.messages:
        message.print()

    exit(1)
