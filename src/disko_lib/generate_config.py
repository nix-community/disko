from disko_lib.logging import DiskoMessage
from disko_lib.messages.msgs import (
    help_generate_partial_failure,
)
from disko_lib.result import DiskoError, DiskoPartialSuccess, DiskoResult, DiskoSuccess
from disko_lib.types.device import BlockDevice
from disko_lib.json_types import JsonDict
import disko_lib.types.disk as disk


def generate_config(devices: list[BlockDevice] = []) -> DiskoResult[JsonDict]:
    error = DiskoError([], "generate disko config")

    config: dict[str, JsonDict] = {
        "disk": {},
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {},
    }
    successful_sections = []
    failed_sections = []

    disk_config = disk.generate_config(devices)
    if isinstance(disk_config, DiskoSuccess):
        config["disk"] = disk_config.value
        successful_sections.append("disk")
    else:
        error.extend(disk_config)
        failed_sections.append("disk")
        if isinstance(disk_config, DiskoPartialSuccess):
            config["disk"] = disk_config.value
            successful_sections.append("disk")

    # TODO: Add generation for ZFS, MDADM, LVM, etc.
    successful_sections.append("lvm_vg")
    successful_sections.append("mdadm")
    successful_sections.append("nodev")
    successful_sections.append("zpool")

    final_config: JsonDict = {"disko": {"devices": config}}  # type: ignore[dict-item]

    if not failed_sections:
        return DiskoSuccess(final_config, "generate disko config")

    if not successful_sections:
        return error

    error.append(
        DiskoMessage(
            help_generate_partial_failure,
            partial_config=final_config,
            successful=successful_sections,
            failed=failed_sections,
        )
    )

    return error.to_partial_success(final_config)
