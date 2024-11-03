from typing import Any
from disko_lib.logging import ReadableMessage


def __bug_help_message(error_code: str) -> ReadableMessage:
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


def bug_success_without_context(*, value: Any) -> list[ReadableMessage]:
    return [
        ReadableMessage(
            "bug",
            f"""
                Success message without context!
                Returned value:
                {value}
            """,
        ),
        __bug_help_message("bug_success_without_context"),
    ]
