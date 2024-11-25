from disko_lib.action import Action, Plan, Step
from disko_lib.config_type import filesystem
from disko_lib.logging import debug
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


def _generate_mount_step(target_config: filesystem) -> Step:
    if target_config.mountpoint is None:
        return Step.empty("mount")

    return Step(
        "mount",
        [
            # TODO: Only try to mount if the device is not already mounted
            # This will probably require us to change the way we specify steps,
            # as they currently don't allow for conditional execution
            [
                "mount",
                target_config.device,
                target_config.mountpoint,
                "-t",
                target_config.format,
            ]
            + target_config.mountOptions
            + ["-o", "X-mount.mkdir"]
        ],
        "mount filesystem",
    )


def generate_plan(
    actions: set[Action], current_config: filesystem | None, target_config: filesystem
) -> DiskoResult[Plan]:
    debug("Generating plan for filesystem")

    plan = Plan(actions, [])

    current_format = current_config.format if current_config is not None else None
    target_format = target_config.format
    device = target_config.device
    need_to_destroy_current = (
        current_config is not None and current_format != target_format
    )

    debug(
        f"Filesystem {device}: {current_format=}, {target_format=}, {need_to_destroy_current=}"
    )

    if need_to_destroy_current:
        plan.append(
            Step(
                "destroy",
                [[f"mkfs.{target_format}"] + target_config.extraArgs + [device]],
                "destroy current filesystem and create new one",
            )
        )

    plan.append(_generate_mount_step(target_config))

    return DiskoSuccess(plan, "generate filesystem plan")
