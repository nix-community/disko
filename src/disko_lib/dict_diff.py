from typing import Any


# Returns a dict that only contains the keys from `right` that have different values in `left`
def dict_diff(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    new_dict: dict[str, Any] = {}

    for k, right_val in right.items():
        left_val = left.get(k)
        if left_val == right_val:
            continue

        if isinstance(right_val, dict):
            new_dict[k] = dict_diff(left.get(k, {}), right[k])
        else:
            new_dict[k] = right[k]

    for k, left_val in left.items():
        if k not in right:
            # Do not recurse, even if left_val is a dict!
            new_dict[k] = None

    return new_dict
