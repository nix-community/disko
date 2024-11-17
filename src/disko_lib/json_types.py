JsonDict = dict[str, "JsonValue"]
JsonValue = str | int | float | bool | None | list["JsonValue"] | JsonDict
