import json
from pathlib import Path, PosixPath

from disko_lib.messages import err_unsupported_pttype, warn_generate_partial_failure
from disko_lib.result import DiskoPartialSuccess, DiskoSuccess
from disko_lib.generate_config import generate_config
from disko_lib.types import device

CURRENT_DIR = Path(__file__).parent


def test_generate_config_partial_failure_dos_table() -> None:
    with open(CURRENT_DIR / "partial_failure_dos_table-lsblk-output.json") as f:
        lsblk_result = device.list_block_devices(f.read())

    assert isinstance(lsblk_result, DiskoSuccess)

    result = generate_config(lsblk_result.value)

    assert isinstance(result, DiskoPartialSuccess)

    assert result.messages[0].is_message(err_unsupported_pttype)
    assert result.messages[0].details == {
        "pttype": "dos",
        "device": PosixPath("/dev/sda"),
    }

    assert result.messages[1].is_message(warn_generate_partial_failure)
    with open(CURRENT_DIR / "partial_failure_dos_table-generate-result.json") as f:
        assert result.value == json.load(f)  # type: ignore[misc]
    assert result.messages[1].details["failed"] == [PosixPath("/dev/sda")]
    assert result.messages[1].details["successful"] == [
        PosixPath("/dev/sdb"),
        PosixPath("/dev/sdc"),
        PosixPath("/dev/sdd"),
    ]
