from disko_lib.eval_config import eval_config
from disko_lib.messages.msgs import err_missing_arguments, err_too_many_arguments
from disko_lib.result import DiskoError, DiskoSuccess


def test_eval_config_missing_arguments() -> None:
    result = eval_config(disko_file=None, flake=None)
    assert isinstance(result, DiskoError)
    assert result.messages[0].factory == err_missing_arguments
    assert result.context == "validate args"


def test_eval_config_too_many_arguments() -> None:
    result = eval_config(disko_file="foo", flake="bar")
    assert isinstance(result, DiskoError)
    assert result.messages[0].factory == err_too_many_arguments
    assert result.context == "validate args"


def test_eval_config_disk_file_example_simple_efi() -> None:
    result = eval_config(disko_file="example/simple-efi.nix", flake=None)
    assert isinstance(result, DiskoSuccess)
    assert result.value == {
        "disk": {
            "main": {
                "content": {
                    "device": "/dev/disk/by-id/some-disk-id",
                    "efiGptPartitionFirst": True,
                    "partitions": {
                        "ESP": {
                            "alignment": 0,
                            "content": {
                                "device": "/dev/disk/by-partlabel/disk-main-ESP",
                                "extraArgs": [],
                                "format": "vfat",
                                "mountOptions": ["umask=0077"],
                                "mountpoint": "/boot",
                                "postCreateHook": "",
                                "postMountHook": "",
                                "preCreateHook": "",
                                "preMountHook": "",
                                "type": "filesystem",
                            },
                            "device": "/dev/disk/by-partlabel/disk-main-ESP",
                            "end": "+500M",
                            "hybrid": None,
                            "label": "disk-main-ESP",
                            "name": "ESP",
                            "priority": 1000,
                            "size": "500M",
                            "start": "0",
                            "type": "EF00",
                        },
                        "root": {
                            "alignment": 0,
                            "content": {
                                "device": "/dev/disk/by-partlabel/disk-main-root",
                                "extraArgs": [],
                                "format": "ext4",
                                "mountOptions": ["defaults"],
                                "mountpoint": "/",
                                "postCreateHook": "",
                                "postMountHook": "",
                                "preCreateHook": "",
                                "preMountHook": "",
                                "type": "filesystem",
                            },
                            "device": "/dev/disk/by-partlabel/disk-main-root",
                            "end": "-0",
                            "hybrid": None,
                            "label": "disk-main-root",
                            "name": "root",
                            "priority": 9001,
                            "size": "100%",
                            "start": "0",
                            "type": "8300",
                        },
                    },
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "gpt",
                },
                "device": "/dev/disk/by-id/some-disk-id",
                "imageName": "main",
                "imageSize": "2G",
                "name": "main",
                "postCreateHook": "",
                "postMountHook": "",
                "preCreateHook": "",
                "preMountHook": "",
                "type": "disk",
            }
        },
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {},
    }


def test_eval_config_flake_testmachine() -> None:
    result = eval_config(disko_file=None, flake=".#testmachine")
    assert isinstance(result, DiskoSuccess)
    assert result.value == {
        "disk": {
            "main": {
                "content": {
                    "device": "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNXAGB12345",
                    "efiGptPartitionFirst": True,
                    "partitions": {
                        "ESP": {
                            "alignment": 0,
                            "content": {
                                "device": "/dev/disk/by-partlabel/disk-main-ESP",
                                "extraArgs": [],
                                "format": "vfat",
                                "mountOptions": ["umask=0077"],
                                "mountpoint": "/boot",
                                "postCreateHook": "",
                                "postMountHook": "",
                                "preCreateHook": "",
                                "preMountHook": "",
                                "type": "filesystem",
                            },
                            "device": "/dev/disk/by-partlabel/disk-main-ESP",
                            "end": "+512M",
                            "hybrid": None,
                            "label": "disk-main-ESP",
                            "name": "ESP",
                            "priority": 1000,
                            "size": "512M",
                            "start": "0",
                            "type": "EF00",
                        },
                        "boot": {
                            "alignment": 0,
                            "content": None,
                            "device": "/dev/disk/by-partlabel/disk-main-boot",
                            "end": "+1M",
                            "hybrid": None,
                            "label": "disk-main-boot",
                            "name": "boot",
                            "priority": 100,
                            "size": "1M",
                            "start": "0",
                            "type": "EF02",
                        },
                        "root": {
                            "alignment": 0,
                            "content": {
                                "device": "/dev/disk/by-partlabel/disk-main-root",
                                "extraArgs": [],
                                "format": "ext4",
                                "mountOptions": ["defaults"],
                                "mountpoint": "/",
                                "postCreateHook": "",
                                "postMountHook": "",
                                "preCreateHook": "",
                                "preMountHook": "",
                                "type": "filesystem",
                            },
                            "device": "/dev/disk/by-partlabel/disk-main-root",
                            "end": "-0",
                            "hybrid": None,
                            "label": "disk-main-root",
                            "name": "root",
                            "priority": 9001,
                            "size": "100%",
                            "start": "0",
                            "type": "8300",
                        },
                    },
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "gpt",
                },
                "device": "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNXAGB12345",
                "imageName": "main",
                "imageSize": "2G",
                "name": "main",
                "postCreateHook": "",
                "postMountHook": "",
                "preCreateHook": "",
                "preMountHook": "",
                "type": "disk",
            }
        },
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {},
    }
