from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any

from lib.result import DiskoError, DiskoResult, DiskoSuccess
from lib.run_cmd import run

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
    def from_json_dict(cls, json_dict: dict[str, Any]) -> "BlockDevice":
        children = [
            cls.from_json_dict(child_dict)
            for child_dict in json_dict.get("children", [])
        ]

        # The mountpoints field will be a list containing a single null if there are no mountpoints
        mountpoints = json_dict["mountpoints"] or []
        if not any(mountpoints):
            mountpoints = []

        # When we request the output fields from lsblk, the keys are guaranteed to exists,
        # but some might be null. Set a default value for the fields we have observed to be optional.
        return cls(
            children=children,
            id_link=json_dict["id-link"],
            fstype=json_dict["fstype"] or "",
            fssize=json_dict["fssize"] or "",
            fsuse_pct=json_dict["fsuse%"] or "",
            kname=json_dict["kname"],
            label=json_dict["label"] or "",
            model=json_dict["model"] or "",
            partflags=json_dict["partflags"] or "",
            partlabel=json_dict["partlabel"] or "",
            partn=json_dict["partn"],
            parttype=json_dict["parttype"] or "",
            parttypename=json_dict["parttypename"] or "",
            partuuid=json_dict["partuuid"] or "",
            path=Path(json_dict["path"]),
            phy_sec=json_dict["phy-sec"],
            pttype=json_dict["pttype"],
            rev=json_dict["rev"] or "",
            serial=json_dict["serial"] or "",
            size=json_dict["size"],
            start=json_dict["start"] or "",
            mountpoint=json_dict["mountpoint"] or "",
            mountpoints=mountpoints,
            type=json_dict["type"],
            uuid=json_dict["uuid"] or "",
        )


def list_block_devices() -> DiskoResult[list[BlockDevice]]:
    lsblk_result = run(
        ["lsblk", "--json", "--tree", "--output", ",".join(LSBLK_OUTPUT_FIELDS)]
    )

    if isinstance(lsblk_result, DiskoError):
        return lsblk_result

    # We trust the output of `lsblk` to be valid JSON
    lsblk_json: list[dict[str, Any]] = json.loads(lsblk_result.value)["blockdevices"]

    blockdevices = [BlockDevice.from_json_dict(dev) for dev in lsblk_json]

    return DiskoSuccess(blockdevices, "list block devices")
