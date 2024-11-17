from disko_lib.messages.msgs import (
    err_unsupported_pttype,
    warn_generate_partial_failure,
)

from ..logging import DiskoMessage, debug
from ..result import DiskoError, DiskoResult, DiskoSuccess
from ..types.device import BlockDevice, list_block_devices
from ..json_types import JsonDict
from . import gpt


def _generate_content(device: BlockDevice) -> DiskoResult[JsonDict]:
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


def generate_config(devices: list[BlockDevice] = []) -> DiskoResult[JsonDict]:
    block_devices = devices
    if not block_devices:
        lsblk_result = list_block_devices()

        if isinstance(lsblk_result, DiskoError):
            return lsblk_result

        block_devices = lsblk_result.value

    debug(f"Generating config for devices {[d.path for d in block_devices]}")

    disks: JsonDict = {}
    error = DiskoError([], "generate disk config")
    failed_devices = []
    successful_devices = []

    for device in block_devices:
        content = _generate_content(device)

        if isinstance(content, DiskoError):
            error.extend(content)
            failed_devices.append(device.path)
            continue

        disks[f"MODEL:{device.model},SN:{device.serial}"] = {
            "device": device.kname,
            "type": device.type,
            "content": content.value,
        }
        successful_devices.append(device.path)

    config: JsonDict = {"disks": disks}

    if not failed_devices:
        return DiskoSuccess(config, "generate disk config")

    if successful_devices:
        error.append(
            DiskoMessage(
                warn_generate_partial_failure,
                partial_config=config,
                failed_devices=failed_devices,
                successful_devices=successful_devices,
            ),
        )

    return error
