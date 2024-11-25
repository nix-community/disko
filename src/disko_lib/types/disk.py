from typing import cast

from disko_lib.action import Action, Plan, Step
from disko_lib.config_type import DiskoConfig, disk, gpt, deviceType
from disko_lib.messages.msgs import (
    err_disk_not_found,
    err_duplicated_disk_devices,
    err_unsupported_pttype,
    warn_generate_partial_failure,
)
from disko_lib.messages.bugs import bug_unsupported_device_content_type
from disko_lib.utils import find_by_predicate, find_duplicates
import disko_lib.types.gpt

from ..logging import DiskoMessage, debug
from ..result import DiskoError, DiskoResult, DiskoSuccess
from ..types.device import BlockDevice, list_block_devices
from ..json_types import JsonDict


def _generate_config_content(device: BlockDevice) -> DiskoResult[JsonDict]:
    match device.pttype:
        case "gpt":
            return disko_lib.types.gpt.generate_config(device)
        case _:
            return DiskoError.single_message(
                err_unsupported_pttype,
                "generate disk config",
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
        content = _generate_config_content(device)

        if isinstance(content, DiskoError):
            error.extend(content)
            failed_devices.append(device.path)
            continue

        disks[f"MODEL:{device.model},SN:{device.serial}"] = {
            "device": f"/dev/{device.kname}",
            "type": device.type,
            "content": content.value,
        }
        successful_devices.append(device.path)

    if not failed_devices:
        return DiskoSuccess(disks, "generate disk config")

    if not successful_devices:
        return error

    error.append(
        DiskoMessage(
            warn_generate_partial_failure,
            kind="disk",
            failed=failed_devices,
            successful=successful_devices,
        )
    )
    return error.to_partial_success(disks)


def _generate_plan_content(
    actions: set[Action],
    name: str,
    device: str,
    current_content: deviceType,
    target_content: deviceType,
) -> DiskoResult[Plan]:
    if target_content is None:
        debug(f"Element '{name}': No target content")
        return DiskoSuccess(Plan(actions, []), f"generate '{name}' content plan")

    target_type = target_content.type

    if current_content is not None:
        assert (
            current_content.type == target_type
        ), "BUG! Device content type mismatch, should've been resolved earlier!"

    match target_type:
        case "gpt":
            return disko_lib.types.gpt.generate_plan(
                actions, cast(gpt | None, current_content), cast(gpt, target_content)
            )
        case _:
            return DiskoError.single_message(
                bug_unsupported_device_content_type,
                "generate disk plan",
                name=name,
                device=device,
                type=target_type,
            )


def generate_plan(
    actions: set[Action], current_status: DiskoConfig, target_config: DiskoConfig
) -> DiskoResult[Plan]:
    debug("Generating plan for disko config")

    error = DiskoError([], "generate disk plan")
    plan = Plan(actions)

    current_disks = current_status.disk
    target_disks = target_config.disk

    target_devices = [d.device for d in target_disks.values()]

    if duplicate_devices := find_duplicates(target_devices):
        error.append(
            DiskoMessage(
                err_duplicated_disk_devices,
                devices=target_devices,
                duplicates=duplicate_devices,
            )
        )

    current_disks_by_target_name: dict[str, disk] = {}

    # Create plan for this disk
    for name, target_disk_config in target_disks.items():
        device = target_disk_config.device
        _, current_disk_config = find_by_predicate(
            current_disks, lambda k, v: v.device == device
        )
        disk_exists = current_disk_config is not None
        current_type = current_disk_config.type if current_disk_config else None
        target_type = target_disk_config.type
        disk_has_same_type = current_type == target_type

        debug(
            f"Disk '{name}': {device=}, {disk_exists=}, {disk_has_same_type=}, {current_type=}, {target_type=}"
        )

        # Can't use disk_exists here, mypy doesn't understand that it
        # narrows the type of current_disk_config
        if current_disk_config is None:
            error.append(
                DiskoMessage(
                    err_disk_not_found,
                    disk=name,
                    device=device,
                )
            )
            continue

        current_disks_by_target_name[name] = current_disk_config

        if disk_has_same_type:
            continue

        plan.append(
            Step(
                "destroy",
                [[f"disk-deactivate {device}"]],
                f"destroy partition table on `{name}`, at {device}",
            )
        )

    # Create content plan
    for name, target_disk_config in target_disks.items():
        current_content = None
        current_disk_config = current_disks_by_target_name.get(name)
        if current_disk_config is not None:
            current_content = current_disk_config.content

        result = _generate_plan_content(
            actions,
            name,
            target_disk_config.device,
            current_content,
            target_disk_config.content,
        )

        if isinstance(result, DiskoError):
            error.extend(result)
            continue

        plan.extend(result.value)

    if error:
        return error

    return DiskoSuccess(plan, "generate disk plan")
