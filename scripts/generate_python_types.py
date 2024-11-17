#!/usr/bin/env python3

import io
import json
import sys
from typing import Any, Callable, Mapping, TypeGuard, TypeVar, TypedDict, cast

JsonDict = dict[str, "JsonValue"]
JsonValue = str | int | float | bool | None | list["JsonValue"] | JsonDict


class TypeDefinition(TypedDict):
    type: str | JsonDict
    default: JsonValue
    description: str


def is_type(type_field: JsonValue) -> TypeGuard[TypeDefinition]:
    if not isinstance(type_field, dict):
        return False
    return set(type_field.keys()) == {"default", "description", "type"}


def parse_type(
    containing_class: str, field_name: str, type_field: str | dict[str, Any]
) -> tuple[str, io.StringIO | None]:
    """Parse a type field into a Python type annotation.

    If the type is a class itself, the second element of the tuple
    will be a buffer containing the class definition.
    """

    if isinstance(type_field, str):
        return _parse_simple_type(type_field), None
    elif isinstance(type_field, dict):
        if type_field.get("__isCompositeType"):
            return _parse_composite_type(containing_class, field_name, type_field)
        else:
            class_name = f"{containing_class}_{field_name}"
            class_code, inner_types_code = generate_class(class_name, type_field)

            if not inner_types_code:
                inner_types_code = io.StringIO()

            inner_types_code.write("\n\n")
            inner_types_code.write(class_code)

            return class_name, inner_types_code

    else:
        raise ValueError(f"Invalid type field: {type_field}")


def _parse_composite_type(
    containing_class: str, field_name: str, type_dict: dict[str, Any]
) -> tuple[str, io.StringIO | None]:
    assert isinstance(type_dict["type"], str)

    type_name, type_code = None, None
    if "subType" in type_dict:
        try:
            type_name, type_code = parse_type(
                containing_class, field_name, type_dict["subType"]
            )
        except Exception as e:
            e.add_note(f"Error in subType {type_dict["subType"]}")
            raise e

    match type_dict["type"]:
        case "attrsOf":
            return f"dict[str, {type_name}]", type_code
        case "listOf":
            return f"list[{type_name}]", type_code
        case "nullOr":
            return f"None | {type_name}", type_code
        case "oneOf":
            type_code = io.StringIO()
            type_names = []
            for sub_type in type_dict["types"]:
                try:
                    sub_type_name, sub_type_code = parse_type(
                        containing_class, field_name, sub_type
                    )
                except Exception as e:
                    e.add_note(f"Error in subType {sub_type}")
                    raise e

                type_names.append(sub_type_name)
                if sub_type_code:
                    type_code.write(sub_type_code.getvalue())

            # Can't use | syntax in all cases, Union always works
            return f'Union[{", ".join(type_names)}]', type_code
        case "enum":
            return (
                f'Literal[{", ".join(f"{repr(value)}" for value in type_dict["choices"])}]',
                None,
            )
        case _:
            return _parse_simple_type(type_dict["type"]), None


def _parse_simple_type(type_str: str) -> str:
    match type_str:
        case "str":
            return "str"
        case "absolute-pathname":
            return "str"
        case "bool":
            return "bool"
        case "int":
            return "int"
        case "anything":
            return "Any"
        # Set up discriminated unions to reduce error messages when validation fails
        case "deviceType":
            return '"deviceType" = Field(..., discriminator="type")'
        case "partitionType":
            return '"partitionType" = Field(..., discriminator="type")'
        case _:
            # Probably a type alias, needs to be quoted in case the type is defined later
            return f'"{type_str}"'


def parse_field(
    containing_class: str, field_name: str, field: str | JsonDict
) -> tuple[str, io.StringIO | None]:
    if isinstance(field, str):
        return _parse_simple_type(field), None

    if is_type(field):
        return parse_type(containing_class, field_name, field["type"])

    class_name = f"{containing_class}_{field_name}"
    class_code, inner_types_code = generate_class(class_name, field)

    if not inner_types_code:
        inner_types_code = io.StringIO()

    inner_types_code.write("\n\n")
    inner_types_code.write(class_code)

    return class_name, inner_types_code


def generate_type_alias(
    name: str, type_spec: str | dict[str, Any]
) -> io.StringIO | None:
    buffer = io.StringIO()

    try:
        type_code, sub_type_code = parse_type(name, "", type_spec)
    except ValueError:
        return None

    if sub_type_code:
        buffer.write(sub_type_code.getvalue())
        buffer.write("\n\n")

    buffer.write(f"{name} = {type_code}")
    buffer.write("\n\n")

    return buffer


def generate_class(name: str, fields: dict[str, Any]) -> tuple[str, io.StringIO | None]:
    assert isinstance(fields, dict)

    contained_classes_buffer = io.StringIO()

    buffer = io.StringIO()
    buffer.write(f"class {name}(BaseModel):\n")

    for field_name, field in fields.items():
        try:
            type_name, type_code = parse_field(name, field_name, field)
        except Exception as e:
            e.add_note(f"Error in field {field_name}: {field}")
            raise e

        if type_code:
            contained_classes_buffer.write(type_code.getvalue())

        buffer.write(f"    {field_name}: {type_name}\n")

    if contained_classes_buffer.tell() == 0:
        return buffer.getvalue(), None

    return buffer.getvalue(), contained_classes_buffer


T = TypeVar("T", bound=JsonValue)


def transform_dict_keys(d: T, transform_fn: Callable[[str], str]) -> T:
    if not isinstance(d, Mapping):
        return d

    return cast(
        T,
        {transform_fn(k): transform_dict_keys(v, transform_fn) for k, v in d.items()},
    )


def generate_python_code(schema: JsonDict) -> io.StringIO:
    assert isinstance(schema, dict)

    # Convert disallowed characters in Python identifiers
    schema = transform_dict_keys(schema, lambda k: k.replace("-", "_"))

    buffer = io.StringIO()

    buffer.write(
        """# File generated by scripts/generate_python_types.py
# Ignore warnings that decorators contain Any
# mypy: disable-error-code="misc"
# Disable auto-formatting for this file
# fmt: off
from typing import Any, Literal, Union
from pydantic import BaseModel, Field


"""
    )

    for type_name, fields in schema.items():
        assert isinstance(fields, dict)
        if "__isCompositeType" in fields:
            try:
                alias_content, type_code = _parse_composite_type(type_name, "", fields)
            except Exception as e:
                e.add_note(f"Error in composite type {type_name}")
                raise e

            if type_code:
                buffer.write(type_code.getvalue())
                buffer.write("\n\n")

            buffer.write(f"{type_name} = {alias_content}")
            buffer.write("\n\n")
            continue

        try:
            class_code, inner_types_code = generate_class(type_name, fields)
        except Exception as e:
            e.add_note(f"Error in class {type_name}")
            raise e

        if inner_types_code:
            buffer.write(inner_types_code.getvalue())
            buffer.write("\n\n")

        buffer.write(class_code)
        buffer.write("\n\n")

    buffer.write(
        """
class DiskoConfig(BaseModel):
    disk: dict[str, disk]
    lvm_vg: dict[str, lvm_vg]
    mdadm: dict[str, mdadm]
    nodev: dict[str, nodev]
    zpool: dict[str, zpool]
"""
    )

    return buffer


def main(in_file: str, out_file: str) -> None:
    with open(in_file) as f:
        schema = json.load(f)

    code_buffer = generate_python_code(schema)

    with open(out_file, "w") as f:
        f.write(code_buffer.getvalue())


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(
            """Usage: generate_python_types.py <in_file> <out_file>
Recommendation: Go to the root of this repository and run

    nix build .#checks.x86_64-linux.jsonTypes

to generate the JSON schema file first, then run

    ./scripts/generate_python_types.py result src/disko_lib/config_types.py
"""
        )
        sys.exit(1)

    main(sys.argv[1], sys.argv[2])
