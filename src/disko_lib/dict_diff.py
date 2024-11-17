from .json_types import JsonDict


def dict_diff(left: JsonDict, right: JsonDict) -> JsonDict:
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
    new_dict: JsonDict = {}

    for k, right_val in right.items():
        left_val = left.get(k)
        if left_val == right_val:
            continue

        if not isinstance(right_val, dict):
            new_dict[k] = right_val
            continue

        if not isinstance(left_val, dict):
            left_val = {}

        diffed_right_val = dict_diff(left_val, right_val)
        if not left_val:
            diffed_right_val["_new"] = True

        new_dict[k] = diffed_right_val

    for k, left_val in left.items():
        if k not in right:
            # Do not recurse, even if left_val is a dict!
            # Recursion is already done in the first loop.
            new_dict[k] = None

    return new_dict
