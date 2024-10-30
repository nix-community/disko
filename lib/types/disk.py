from typing import Any

from lib.logging import DiskoMessage, debug
from lib.result import DiskoError, DiskoResult, DiskoSuccess
from lib.types.device import BlockDevice, list_block_devices
import lib.types.gpt as gpt


def _generate_content(device: BlockDevice) -> DiskoResult[dict[str, Any]]:
    match device.pttype:
        case "gpt":
            return gpt.generate_config(device)
        case _:
            return DiskoError.single_message(
                "ERR_UNSUPPORTED_PTTYPE",
                {"device": device.path, "pttype": device.pttype},
                "generate disk content",
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
                "WARN_GENERATE_PARTIAL_FAILURE",
                {
                    "partial_config": {"disks": disks},
                    "failed_devices": failed_devices,
                    "successful_devices": successful_devices,
                },
            )
        ],
        "generate disk config",
    )
