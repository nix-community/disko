from disko_lib.action import Action, Plan
from disko_lib.config_type import DiskoConfig
from disko_lib.result import DiskoResult
import disko_lib.types.disk as disk


def generate_plan(
    actions: set[Action], current_status: DiskoConfig, target_config: DiskoConfig
) -> DiskoResult[Plan]:
    # TODO: Add generation for ZFS, MDADM, LVM, etc.
    return disk.generate_plan(actions, current_status, target_config)
