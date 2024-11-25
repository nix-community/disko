from typing import Iterable, TypeVar, Callable

T = TypeVar("T")


def find_by_predicate(
    dct: dict[str, T], predicate: Callable[[str, T], bool]
) -> tuple[str, T] | tuple[None, None]:
    for k, v in dct.items():
        if predicate(k, v):
            return k, v
    return None, None


def find_duplicates(it: Iterable[T]) -> set[T]:
    seen = set()
    duplicates = set()
    for item in it:
        if item in seen:
            duplicates.add(item)
        else:
            seen.add(item)
    return duplicates
