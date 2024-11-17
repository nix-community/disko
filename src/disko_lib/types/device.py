from dataclasses import dataclass
import json
from pathlib import Path
from typing import cast

from ..result import DiskoError, DiskoResult, DiskoSuccess
from ..run_cmd import run
from ..json_types import JsonDict

# To see what other fields are available in the lsblk output and what
# sort of values you can expect from them, run:
# lsblk -O | less -S
LSBLK_OUTPUT_FIELDS = [
    "ID-LINK",
    "FSTYPE",
    "FSSIZE",
    "FSUSE%",
    "KNAME",
    "LABEL",
    "MODEL",
    "PARTFLAGS",
    "PARTLABEL",
    "PARTN",
    "PARTTYPE",
    "PARTTYPENAME",
    "PARTUUID",  # The UUID used for /dev/disk/by-partuuid
    "PATH",  # The canonical path of the block device
    "PHY-SEC",
    "PTTYPE",
    "REV",
    "SERIAL",
    "SIZE",
    "START",
    "MOUNTPOINT",  # Canonical mountpoint
    "MOUNTPOINTS",  # All mountpoints, including e.g. bind mounts
    "TYPE",
    "UUID",  # The UUID used for /dev/disk/by-uuid, if available
]


# Could think about splitting this into multiple classes based on the type field
# Would make access to the fields more type safe
@dataclass
class BlockDevice:
    id_link: str
    fstype: str
    fssize: str
    fsuse_pct: str
    kname: str
    label: str
    model: str
    partflags: str
    partlabel: str
    partn: int | None
    parttype: str
    parttypename: str
    partuuid: str
    path: Path
    phy_sec: int
    pttype: str
    rev: str
    serial: str
    size: str
    start: str
    mountpoint: str
    mountpoints: list[str]
    type: str
    uuid: str
    children: list["BlockDevice"]

    @classmethod
    def from_json_dict(cls, json_dict: JsonDict) -> "BlockDevice":
        children_list = json_dict.get("children", [])
        assert isinstance(children_list, list)
        children = []
        for child_dict in children_list:
            assert isinstance(child_dict, dict)
            children.append(cls.from_json_dict(child_dict))

        # The mountpoints field will be a list containing a single null if there are no mountpoints
        mountpoints = cast(list[str], json_dict["mountpoints"]) or []
        if not any(mountpoints):
            mountpoints = []

        # When we request the output fields from lsblk, the keys are guaranteed to exists,
        # but some might be null. Set a default value for the fields we have observed to be optional.
        return cls(
            children=children,
            id_link=cast(str, json_dict["id-link"]),
            fstype=cast(str, json_dict["fstype"]) or "",
            fssize=cast(str, json_dict["fssize"]) or "",
            fsuse_pct=cast(str, json_dict["fsuse%"]) or "",
            kname=cast(str, json_dict["kname"]),
            label=cast(str, json_dict["label"]) or "",
            model=cast(str, json_dict["model"]) or "",
            partflags=cast(str, json_dict["partflags"]) or "",
            partlabel=cast(str, json_dict["partlabel"]) or "",
            partn=cast(int, json_dict["partn"]),
            parttype=cast(str, json_dict["parttype"]) or "",
            parttypename=cast(str, json_dict["parttypename"]) or "",
            partuuid=cast(str, json_dict["partuuid"]) or "",
            path=Path(cast(str, json_dict["path"])),
            phy_sec=cast(int, json_dict["phy-sec"]),
            pttype=cast(str, json_dict["pttype"]),
            rev=cast(str, json_dict["rev"]) or "",
            serial=cast(str, json_dict["serial"]) or "",
            size=cast(str, json_dict["size"]),
            start=cast(str, json_dict["start"]) or "",
            mountpoint=cast(str, json_dict["mountpoint"]) or "",
            mountpoints=mountpoints,
            type=cast(str, json_dict["type"]),
            uuid=cast(str, json_dict["uuid"]) or "",
        )


def run_lsblk() -> DiskoResult[str]:
    return run(["lsblk", "--json", "--tree", "--output", ",".join(LSBLK_OUTPUT_FIELDS)])


def list_block_devices(lsblk_output: str = "") -> DiskoResult[list[BlockDevice]]:
    if not lsblk_output:
        lsblk_result = run_lsblk()

        if isinstance(lsblk_result, DiskoError):
            return lsblk_result

        lsblk_output = lsblk_result.value

    # We trust the output of `lsblk` to be valid JSON
    output: JsonDict = json.loads(lsblk_output)
    lsblk_json: list[JsonDict] = output["blockdevices"]  # type: ignore[assignment]

    blockdevices = [BlockDevice.from_json_dict(dev) for dev in lsblk_json]

    return DiskoSuccess(blockdevices, "list block devices")
