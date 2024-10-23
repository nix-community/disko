#!/usr/bin/env nu

use disko.nu

use std assert

assert equal ("example/simple-efi.nix" | path expand | disko eval-disko-file) {
    success: true,
    value: {
        "disk": {
            "main": {
            "content": {
                "device": "/dev/disk/by-id/some-disk-id",
                "efiGptPartitionFirst": true,
                "partitions": {
                "ESP": {
                    "alignment": 0,
                    "content": {
                    "device": "/dev/disk/by-partlabel/disk-main-ESP",
                    "extraArgs": [],
                    "format": "vfat",
                    "mountOptions": [
                        "umask=0077"
                    ],
                    "mountpoint": "/boot",
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "filesystem"
                    },
                    "device": "/dev/disk/by-partlabel/disk-main-ESP",
                    "end": "+500M",
                    "hybrid": null,
                    "label": "disk-main-ESP",
                    "name": "ESP",
                    "priority": 1000,
                    "size": "500M",
                    "start": "0",
                    "type": "EF00"
                },
                "root": {
                    "alignment": 0,
                    "content": {
                    "device": "/dev/disk/by-partlabel/disk-main-root",
                    "extraArgs": [],
                    "format": "ext4",
                    "mountOptions": [
                        "defaults"
                    ],
                    "mountpoint": "/",
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "filesystem"
                    },
                    "device": "/dev/disk/by-partlabel/disk-main-root",
                    "end": "-0",
                    "hybrid": null,
                    "label": "disk-main-root",
                    "name": "root",
                    "priority": 9001,
                    "size": "100%",
                    "start": "0",
                    "type": "8300"
                }
                },
                "postCreateHook": "",
                "postMountHook": "",
                "preCreateHook": "",
                "preMountHook": "",
                "type": "gpt"
            },
            "device": "/dev/disk/by-id/some-disk-id",
            "imageName": "main",
            "imageSize": "2G",
            "name": "main",
            "postCreateHook": "",
            "postMountHook": "",
            "preCreateHook": "",
            "preMountHook": "",
            "type": "disk"
            }
        },
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {}
        }
    }

assert equal ("example/with-lib.nix" | path expand | disko eval-disko-file) {
    success: true,
    value: {
        "disk": {
          "/dev/vdb": {
            "content": {
              "device": "/dev/vdb",
              "efiGptPartitionFirst": true,
              "partitions": {
                "boot": {
                  "alignment": 0,
                  "content": null,
                  "device": "/dev/disk/by-partlabel/disk-_dev_vdb-boot",
                  "end": "+1M",
                  "hybrid": null,
                  "label": "disk-_dev_vdb-boot",
                  "name": "boot",
                  "priority": 100,
                  "size": "1M",
                  "start": "0",
                  "type": "EF02"
                },
                "root": {
                  "alignment": 0,
                  "content": {
                    "device": "/dev/disk/by-partlabel/disk-_dev_vdb-root",
                    "extraArgs": [],
                    "format": "ext4",
                    "mountOptions": [
                      "defaults"
                    ],
                    "mountpoint": "/",
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "filesystem"
                  },
                  "device": "/dev/disk/by-partlabel/disk-_dev_vdb-root",
                  "end": "-0",
                  "hybrid": null,
                  "label": "disk-_dev_vdb-root",
                  "name": "root",
                  "priority": 9001,
                  "size": "100%",
                  "start": "0",
                  "type": "8300"
                }
              },
              "postCreateHook": "",
              "postMountHook": "",
              "preCreateHook": "",
              "preMountHook": "",
              "type": "gpt"
            },
            "device": "/dev/vdb",
            "imageName": "_dev_vdb",
            "imageSize": "2G",
            "name": "_dev_vdb",
            "postCreateHook": "",
            "postMountHook": "",
            "preCreateHook": "",
            "preMountHook": "",
            "type": "disk"
          }
        },
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {}
    }
}

assert equal (".#testmachine" | disko eval-flake) {
    success: true,
    value: {
        "disk": {
          "main": {
            "content": {
              "device": "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNXAGB12345",
              "efiGptPartitionFirst": true,
              "partitions": {
                "ESP": {
                  "alignment": 0,
                  "content": {
                    "device": "/dev/disk/by-partlabel/disk-main-ESP",
                    "extraArgs": [],
                    "format": "vfat",
                    "mountOptions": [
                      "umask=0077"
                    ],
                    "mountpoint": "/boot",
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "filesystem"
                  },
                  "device": "/dev/disk/by-partlabel/disk-main-ESP",
                  "end": "+512M",
                  "hybrid": null,
                  "label": "disk-main-ESP",
                  "name": "ESP",
                  "priority": 1000,
                  "size": "512M",
                  "start": "0",
                  "type": "EF00"
                },
                "boot": {
                  "alignment": 0,
                  "content": null,
                  "device": "/dev/disk/by-partlabel/disk-main-boot",
                  "end": "+1M",
                  "hybrid": null,
                  "label": "disk-main-boot",
                  "name": "boot",
                  "priority": 100,
                  "size": "1M",
                  "start": "0",
                  "type": "EF02"
                },
                "root": {
                  "alignment": 0,
                  "content": {
                    "device": "/dev/disk/by-partlabel/disk-main-root",
                    "extraArgs": [],
                    "format": "ext4",
                    "mountOptions": [
                      "defaults"
                    ],
                    "mountpoint": "/",
                    "postCreateHook": "",
                    "postMountHook": "",
                    "preCreateHook": "",
                    "preMountHook": "",
                    "type": "filesystem"
                  },
                  "device": "/dev/disk/by-partlabel/disk-main-root",
                  "end": "-0",
                  "hybrid": null,
                  "label": "disk-main-root",
                  "name": "root",
                  "priority": 9001,
                  "size": "100%",
                  "start": "0",
                  "type": "8300"
                }
              },
              "postCreateHook": "",
              "postMountHook": "",
              "preCreateHook": "",
              "preMountHook": "",
              "type": "gpt"
            },
            "device": "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNXAGB12345",
            "imageName": "main",
            "imageSize": "2G",
            "name": "main",
            "postCreateHook": "",
            "postMountHook": "",
            "preCreateHook": "",
            "preMountHook": "",
            "type": "disk"
          }
        },
        "lvm_vg": {},
        "mdadm": {},
        "nodev": {},
        "zpool": {}
    }
}

assert equal ("." | disko eval-flake) {
    success: false,
    messages: [
        "Flake-uri . does not contain an attribute.",
        "Please append an attribute like \"#foo\" to the flake-uri."
    ]
}

def main [] {
    echo "All tests passed"
}