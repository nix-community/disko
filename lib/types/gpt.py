from typing import Any
from lib.logging import debug
from lib.types import filesystem
from lib.types.device import BlockDevice
from lib.result import DiskoError, DiskoResult, DiskoSuccess


def _add_type_if_required(
    device: BlockDevice, part_config: dict[str, Any]
) -> dict[str, Any]:
    type = {
        "c12a7328-f81f-11d2-ba4b-00a0c93ec93b": "EF00",  # EFI System
        "21686148-6449-6e6f-744e-656564454649": "EF02",  # BIOS boot
    }.get(device.parttype)

    if type:
        part_config["type"] = type

    return part_config


def _generate_name(device: BlockDevice) -> str:
    if device.uuid:
        return f"UUID:{device.uuid}"

    return f"PARTUUID:{device.partuuid}"


def _generate_content(device: BlockDevice) -> DiskoResult[dict[str, Any]]:
    match device.fstype:
        # TODO: Add filesystems that are not supported by `mkfs` here
        case _:
            return filesystem.generate_config(device)


def generate_config(device: BlockDevice) -> DiskoResult[dict[str, Any]]:
    assert (
        device.pttype == "gpt"
    ), f"BUG! gpt.generate_config called with non-gpt device {device.path}"

    debug(f"Generating GPT config for device {device.path}")

    partitions = {}
    error_messages = []
    failed_partitions = []
    successful_partitions = []

    for partition in device.children:
        content = _generate_content(partition)

        if isinstance(content, DiskoError):
            error_messages.extend(content.messages)
            failed_partitions.append(partition.path)
            continue

        partitions[_generate_name(partition)] = _add_type_if_required(
            partition, {"size": partition.size, "content": content.value}
        )
        successful_partitions.append(partition.path)

    if not failed_partitions:
        return DiskoSuccess({"partitions": partitions}, "generate gpt config")

    return DiskoError(error_messages, "generate gpt config")