from disko_lib.dict_diff import dict_diff
from disko_lib.json_types import JsonDict


def test_dict_diff_basic() -> None:
    left: JsonDict = {
        "a": 1,
        "b": 2,
        "c": 3,
        "d": 4,
    }
    right: JsonDict = {
        "a": 1,
        "b": 3,
        "c": 4,
        "e": 5,
    }
    assert dict_diff(left, right) == {
        "b": 3,
        "c": 4,
        "d": None,
        "e": 5,
    }
    assert dict_diff(right, left) == {
        "b": 2,
        "c": 3,
        "d": 4,
        "e": None,
    }
    assert dict_diff(left, left) == {}
    assert dict_diff(right, right) == {}
    assert dict_diff({}, {}) == {}
    assert dict_diff(left, {}) == {
        "a": None,
        "b": None,
        "c": None,
        "d": None,
    }
    assert dict_diff({}, right) == right


def test_dict_diff_arrays() -> None:
    left: JsonDict = {
        "a": [1, 2, 3],
        "b": [4, 5, 6],
        "c": [7, 8, 9],
    }
    right: JsonDict = {
        "a": [1, 2, 3],
        "b": [4, 5, 7],
        "c": [7, 8, 9],
        "d": [10, 11, 12],
    }
    assert dict_diff(left, right) == {
        "b": [4, 5, 7],
        "d": [10, 11, 12],
    }
    assert dict_diff(right, left) == {
        "b": [4, 5, 6],
        "d": None,
    }
    assert dict_diff(left, left) == {}
    assert dict_diff(right, right) == {}
    assert dict_diff(left, {}) == {
        "a": None,
        "b": None,
        "c": None,
    }
    assert dict_diff({}, right) == right


def test_dict_diff_nested() -> None:
    left: JsonDict = {
        "a": {
            "b": {
                "c": 1,
                "d": 2,
            },
            "e": 3,
            "f": 4,
        },
        "g": {
            "h": 4,
        },
        "k": {
            "l": {
                "m": 5,
            },
        },
    }
    right: JsonDict = {
        "a": {
            "b": {
                "c": 1,
                "d": 3,
            },
            "e": 3,
        },
        "g": {
            "h": 4,
            "i": 5,
        },
        "o": {
            "p": 6,
        },
    }
    assert dict_diff(left, right) == {
        "a": {
            "b": {
                "d": 3,
            },
            "f": None,
        },
        "g": {
            "i": 5,
        },
        "k": None,
        "o": {
            "p": 6,
            "_new": True,
        },
    }
    assert dict_diff(right, left) == {
        "a": {
            "b": {
                "d": 2,
            },
            "f": 4,
        },
        "g": {
            "i": None,
        },
        "k": {
            "l": {
                "m": 5,
                "_new": True,
            },
            "_new": True,
        },
        "o": None,
    }
    assert dict_diff(left, left) == {}
    assert dict_diff(right, right) == {}
    assert dict_diff(left, {}) == {
        "a": None,
        "g": None,
        "k": None,
    }
    assert dict_diff({}, right) == {
        "a": {
            "b": {
                "c": 1,
                "d": 3,
                "_new": True,
            },
            "e": 3,
            "_new": True,
        },
        "g": {
            "h": 4,
            "i": 5,
            "_new": True,
        },
        "o": {
            "p": 6,
            "_new": True,
        },
    }
