from typing import Any

from disko_lib.messages.msgs import (
    err_unsupported_pttype,
    warn_generate_partial_failure,
)

from ..logging import DiskoMessage, debug
from ..result import DiskoError, DiskoResult, DiskoSuccess
from ..types.device import BlockDevice, list_block_devices
from . import gpt


def _generate_content(device: BlockDevice) -> DiskoResult[dict[str, Any]]:
    match device.pttype:
        case "gpt":
            return gpt.generate_config(device)
        case _:
            return DiskoError.single_message(
                err_unsupported_pttype,
                "generate disk content",
                device=device.path,
                pttype=device.pttype,
            )


def generate_config(devices: list[BlockDevice] = []) -> DiskoResult[dict[str, Any]]:
    block_devices = devices
    if not block_devices:
        lsblk_result = list_block_devices()

        if isinstance(lsblk_result, DiskoError):
            return lsblk_result

        block_devices = lsblk_result.value

    if isinstance(block_devices, DiskoError):
        return block_devices

    debug(f"Generating config for devices {[d.path for d in block_devices]}")

    disks = {}
    error_messages = []
    failed_devices = []
    successful_devices = []

    for device in block_devices:
        content = _generate_content(device)

        if isinstance(content, DiskoError):
            error_messages.extend(content.messages)
            failed_devices.append(device.path)
            continue

        disks[f"MODEL:{device.model},SN:{device.serial}"] = {
            "device": device.kname,
            "type": device.type,
            "content": content.value,
        }
        successful_devices.append(device.path)

    if not failed_devices:
        return DiskoSuccess({"disks": disks}, "generate disk config")

    if not successful_devices:
        return DiskoError(error_messages, "generate disk config")

    return DiskoError(
        error_messages
        + [
            DiskoMessage(
                warn_generate_partial_failure,
                partial_config={"disks": disks},
                failed_devices=failed_devices,
                successful_devices=successful_devices,
            )
        ],
        "generate disk config",
    )
