from typing import cast
from disko_lib.action import Action, Plan, Step
from disko_lib.config_type import gpt, gpt_partitions, partitionType, filesystem
from disko_lib.messages.bugs import bug_unsupported_partition_content_type
from disko_lib.utils import find_by_predicate
import disko_lib.types.filesystem
from ..logging import debug
from .device import BlockDevice
from ..result import DiskoError, DiskoResult, DiskoSuccess
from ..json_types import JsonDict


def _add_type_if_required(device: BlockDevice, part_config: JsonDict) -> JsonDict:
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


def _generate_config_content(device: BlockDevice) -> DiskoResult[JsonDict]:
    match device.fstype:
        # TODO: Add filesystems that are not supported by `mkfs` here
        case _:
            return disko_lib.types.filesystem.generate_config(device)


def generate_config(device: BlockDevice) -> DiskoResult[JsonDict]:
    assert (
        device.pttype == "gpt"
    ), f"BUG! gpt.generate_config called with non-gpt device {device.path}"

    debug(f"Generating GPT config for device {device.path}")

    partitions: JsonDict = {}
    error = DiskoError([], "generate gpt config")
    failed_partitions = []
    successful_partitions = []

    for index, partition in enumerate(device.children):
        content = _generate_config_content(partition)

        if isinstance(content, DiskoError):
            error.extend(content)
            failed_partitions.append(partition.path)
            continue

        partitions[_generate_name(partition)] = _add_type_if_required(
            partition,
            {"_index": index + 1, "size": partition.size, "content": content.value},
        )
        successful_partitions.append(partition.path)

    if not failed_partitions:
        return DiskoSuccess(
            {"type": "gpt", "partitions": partitions}, "generate gpt config"
        )

    return error


def _generate_plan_content(
    actions: set[Action],
    name: str,
    device: str,
    current_content: partitionType,
    target_content: partitionType,
) -> DiskoResult[Plan]:
    if target_content is None:
        return DiskoSuccess(Plan(actions, []), f"generate '{name}' content plan")

    target_type = target_content.type

    if current_content is not None:
        assert (
            current_content.type == target_type
        ), "BUG! Partition content type mismatch, should've been resolved earlier!"

    match target_type:
        case "filesystem":
            return disko_lib.types.filesystem.generate_plan(
                actions,
                cast(filesystem | None, current_content),
                cast(filesystem, target_content),
            )
        case _:
            return DiskoError.single_message(
                bug_unsupported_partition_content_type,
                "generate partition plan",
                name=name,
                device=device,
                type=target_type,
            )


def _step_clear_partition_table(device: str) -> Step:
    return Step(
        "format", [["sgdisk", "--clear", device]], f"Clear partition table on {device}"
    )


def _partprobe_settle(device: str) -> list[list[str]]:
    # ensure /dev/disk/by-path/..-partN exists before continuing
    return [
        ["partprobe", device],
        ["udevadm", "trigger", "--subsystem-match=block"],
        ["udevadm", "settle"],
    ]


def _sgdisk_create_args(partition_config: gpt_partitions) -> list[str]:
    alignment = partition_config.alignment
    index = partition_config.index
    start = partition_config.start
    end = partition_config.end

    alignment_args = [] if alignment == 0 else [f"--set-alignment={alignment}"]

    return [
        "--align-end",
        *alignment_args,
        f"--new={index}:{start}:{end}",
    ]


def _sgdisk_modify_args(partition_config: gpt_partitions) -> list[str]:
    index = partition_config.index
    label = partition_config.label
    type = partition_config.type

    return [
        f'--change-name="{index}:{label}"',
        f"--typecode=${index}:{type}",
    ]


def _step_modify_partition(device: str, partition_config: gpt_partitions) -> Step:
    return Step(
        "format",
        [
            [
                "sgdisk",
                *_sgdisk_modify_args(partition_config),
                device,
            ]
        ]
        + _partprobe_settle(device),
        "Create partition {}",
    )


def _step_create_partition(device: str, partition_config: gpt_partitions) -> Step:
    return Step(
        "format",
        [
            [
                "sgdisk",
                *_sgdisk_create_args(partition_config),
                *_sgdisk_modify_args(partition_config),
                device,
            ]
        ]
        + _partprobe_settle(device),
        "Create partition {}",
    )


def generate_plan(
    actions: set[Action], current_gpt_config: gpt | None, target_gpt_config: gpt
) -> DiskoResult[Plan]:
    device = target_gpt_config.device
    debug(f"Generating GPT plan for disk {device}")

    if current_gpt_config is None:
        current_partitions = {}
    else:
        current_partitions = current_gpt_config.partitions
    target_partitions = target_gpt_config.partitions

    error_messages = []
    plan = Plan(actions)

    if current_gpt_config is None:
        plan.append(_step_clear_partition_table(device))

    current_partitions_by_target_name: dict[str, gpt_partitions] = {}

    # Create or modify all partitions first
    for name, target_partition in target_partitions.items():
        _, current_partition = find_by_predicate(
            current_partitions, lambda k, v: v.index == target_partition.index
        )

        if not current_partition:
            plan.append(_step_create_partition(device, target_partition))
            continue

        current_partitions_by_target_name[name] = current_partition

        if (
            current_partition.type == target_partition.type
            and current_partition.label == target_partition.label
        ):
            debug(f"Partition {name} has no changes we could apply")
            continue

        # TODO: Determine if something else about the disk changed. Add a warning message if that change
        # can't be applied by disko automatically, (plus a help message that explains how to target just
        # a single disk in case the user wants to make the change destructively) or add the
        # necessary steps to apply the changes
        if "format" not in actions:
            continue

        plan.append(_step_modify_partition(device, target_partition))

    # Then dispatch to all the filesystems
    for name, target_partition in target_partitions.items():
        current_content = None
        current_partition_config = current_partitions_by_target_name.get(name)
        if current_partition_config is not None:
            current_content = current_partition_config.content

        content_plan_result = _generate_plan_content(
            actions,
            name,
            target_partition.device,
            current_content,
            target_partition.content,
        )
        if isinstance(content_plan_result, DiskoError):
            error_messages.append(content_plan_result.messages)
            continue

        plan.extend(content_plan_result.value)

    return DiskoSuccess(plan, "generate gpt plan")
