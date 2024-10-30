from typing import Any
from .device import BlockDevice
from ..result import DiskoResult, DiskoSuccess


def generate_config(device: BlockDevice) -> DiskoResult[dict[str, Any]]:
    assert (
        device.type == "part"
    ), f"BUG! filesystem.generate_config called with non-partition device {device.path}"

    return DiskoSuccess(
        {
            "type": "filesystem",
            "format": device.fstype,
            "mountpoint": device.mountpoint,
        }
    )
