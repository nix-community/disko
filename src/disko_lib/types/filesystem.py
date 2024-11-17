from .device import BlockDevice
from ..result import DiskoResult, DiskoSuccess
from ..json_types import JsonDict


def generate_config(device: BlockDevice) -> DiskoResult[JsonDict]:
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
