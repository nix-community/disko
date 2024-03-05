# Disko-install

Disko-install enhances the normal `nixos-install` with disko's partitioning feature.
It can be started from the NixOS installer but it can also be used to create bootable USB-Sticks from your normal workstation.
Furthermore `disko-install` has a mount mode that will only mount but not destroy existing partitions.
The mount mode can be used to mount and repair existing NixOS installations.
This document provides a comprehensive guide on how to use Disko-Install, including examples for typical usage scenarios.

## Requirements

- a Linux system with Nix installed.
- a target disk or partition for the NixOS installation.
- a Nix flake that defines your desired NixOS configuration.

## Usage

### Fresh Installation

For a fresh installation, where Disko-Install will handle partitioning and setting up the disk, use the following syntax:

```console
sudo nix run 'github:nix-community/disko#disko-install' -- --flake <flake-url>#<flake-attr> --disk <disk-name> <disk-device>
```

Example:

First run `nixos-generate-config --root /tmp/config --no-filesystems` and
edit `configuration.nix` to your liking.

Than add the following `flake.nix` inside `/tmp/config/etc/nixos`.
In this example we assume a system that has been booted with EFI:

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, disko, nixpkgs }: {
    nixosConfigurations.mymachine = nixpkgs.legacyPackages.x86_64-linux.nixos [
      ./configuration.nix
      disko.nixosModules.disko
      {
        disko.devices = {
          disk = {
            main = {
              # When using disko-install, we will overwrite this value from the commandline
              device = "/dev/disk/by-id/some-disk-id";
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  MBR = {
                    type = "EF02"; # for grub MBR
                    size = "1M";
                  };
                  ESP = {
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                    };
                  };
                  root = {
                    size = "100%";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                    };
                  };
                };
              };
            };
          };
        };
      }
    ];
  };
}
```

Identify the device name that you want to install NixOS to:

```console
$ lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda           8:0    1 14.9G  0 disk
└─sda1        8:1    1 14.9G  0 part
zd0         230:0    0   10G  0 disk
├─zd0p1     230:1    0  500M  0 part
└─zd0p2     230:2    0  9.5G  0 part /mnt
nvme0n1     259:0    0  1.8T  0 disk
├─nvme0n1p1 259:1    0    1G  0 part /boot
├─nvme0n1p2 259:2    0   16M  0 part
├─nvme0n1p3 259:3    0  250G  0 part
└─nvme0n1p4 259:4    0  1.6T  0 part
```

In our example, we want to install to a USB-stick (/dev/sda):

```console
$ sudo nix run 'github:nix-community/disko#disko-install' -- --flake '/tmp/config/etc/nixos#mymachine' --disk main /dev/sda
```

Afterwards you can test your USB-stick by either selecting during the boot
or attaching it to a qemu-vm:

```
$ sudo qemu-kvm -enable-kvm -hda /dev/sda
```
