from typing import Any


def dict_diff(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    """Return a dict that only contains the keys and values of `right`
    that are different from those in `left`.

    >>> dict_diff({"a": 1, "b": 2}, {"a": 1, "b": 3})
    {'b': 3}

    Keys that are in `left` but not in `right` get the value `None`.

    >>> dict_diff({"a": 1, "b": 2}, {"a": 1})
    {'b': None}

    Dicts are compared recursively.

    >>> dict_diff({"a": {"b": 2}}, {"a": {"b": 3}})
    {'a': {'b': 3}}

    If a dict is missing in `left`, it gets the special key "_new" set
    to True to differentiate it from a dict that was present but changed.

    >>> dict_diff({"a": {"b": 1}}, {"a": {"b": 3}, "c": {"d": 4}})
    {'a': {'b': 3}, 'c': {'d': 4, '_new': True}}
    """
    new_dict: dict[str, Any] = {}

    for k, right_val in right.items():
        left_val = left.get(k)
        if left_val == right_val:
            continue

        if not isinstance(right_val, dict):
            new_dict[k] = right[k]
            continue

        new_dict[k] = dict_diff(left.get(k, {}), right[k])
        if not left_val:
            new_dict[k]["_new"] = True

    for k, left_val in left.items():
        if k not in right:
            # Do not recurse, even if left_val is a dict!
            # Recursion is already done in the first loop.
            new_dict[k] = None

    return new_dict
