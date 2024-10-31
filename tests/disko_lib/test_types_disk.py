import json
from pathlib import Path, PosixPath
import pytest

from disko_lib.result import DiskoError, DiskoSuccess
from disko_lib.types import disk
from disko_lib.types import device

CURRENT_DIR = Path(__file__).parent


def test_generate_config_partial_failure_dos_table() -> None:
    with open(CURRENT_DIR / "lsblk-output.json") as f:
        lsblk_result = device.list_block_devices(f.read())

    assert isinstance(lsblk_result, DiskoSuccess)

    result = disk.generate_config(lsblk_result.value)

    assert isinstance(result, DiskoError)

    assert result.messages[0].code == "ERR_UNSUPPORTED_PTTYPE"
    assert result.messages[0].details == {
        "pttype": "dos",
        "device": PosixPath("/dev/sdc"),
    }

    assert result.messages[1].code == "WARN_GENERATE_PARTIAL_FAILURE"
    with open(CURRENT_DIR / "generate-result.json") as f:
        assert result.messages[1].details["partial_config"] == json.load(f)
    assert result.messages[1].details["failed_devices"] == [PosixPath("/dev/sdc")]
    assert result.messages[1].details["successful_devices"] == [
        PosixPath("/dev/sda"),
        PosixPath("/dev/sdb"),
        PosixPath("/dev/sdd"),
    ]
