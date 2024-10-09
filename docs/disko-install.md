# disko-install

**disko-install** enhances the normal `nixos-install` with disko's partitioning
feature. It can be started from the NixOS installer but it can also be used to
create bootable USB-Sticks from your normal workstation. Furthermore
`disko-install` has a mount mode that will only mount but not destroy existing
partitions. The mount mode can be used to mount and repair existing NixOS
installations. This document provides a comprehensive guide on how to use
**disko-install**, including examples for typical usage scenarios.

## Requirements

- a Linux system with Nix installed.
- a target disk or partition for the NixOS installation.
- a Nix flake that defines your desired NixOS configuration.

## Usage

### Fresh Installation

For a fresh installation, where **disko-install** will handle partitioning and
setting up the disk, use the following syntax:

```console
sudo nix run 'github:nix-community/disko#disko-install/latest' -- --flake <flake-url>#<flake-attr> --disk <disk-name> <disk-device>
```

Example:

First run `nixos-generate-config --root /tmp/config --no-filesystems` and edit
`configuration.nix` to your liking.

Then add the following `flake.nix` inside `/tmp/config/etc/nixos`. In this
example we assume a system that has been booted with EFI:

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.disko.url = "github:nix-community/disko/latest";
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
                    priority = 1; # Needs to be first partition
                  };
                  ESP = {
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [ "umask=0077" ];
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
$ sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake '/tmp/config/etc/nixos#mymachine' --disk main /dev/sda
```

Afterwards you can test your USB-stick by either selecting during the boot or
attaching it to a qemu-vm:

```
$ sudo qemu-kvm -enable-kvm -hda /dev/sda
```

### Persisting boot entries to EFI vars flash

**disko-install** is designed for NixOS installations on portable storage or
disks that may be transferred between computers. As such, it does not modify the
host's NVRAM by default. To ensure your NixOS installation boots seamlessly on
new hardware or to prioritize it in your current machine's boot order, use the
--write-efi-boot-entries option:

```console
$ sudo nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '/tmp/config/etc/nixos#mymachine' --disk main /dev/sda
```

This command installs NixOS with **disko-install** and sets the newly installed
system as the default boot option, without affecting the flexibility to boot
from other devices if needed.

### Using disko-install in an offline installer

If you want to use **disko-install** from a custom installer without internet,
you need to make sure that in addition to the toplevel of your NixOS closure
that you plan to install, it also needs to contain  **diskoScript** and all the
flake inputs for evaluation.

#### Example configuration to install

Add this to your flake.nix output:

```nix
{
  nixosConfigurations.your-machine = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    # to pass this flake into your configuration (see the example below)
    specialArgs = {inherit self;};
    modules = [
      {
        # TODO: add your NixOS configuration here, don't forget your hardware-configuration.nix as well!
        boot.loader.systemd-boot.enable = true;
        imports = [ self.inputs.disko.nixosModules.disko ];
        disko.devices = {
          disk = {
            vdb = {
              device = "/dev/disk/by-id/some-disk-id";
              type = "disk";
              content = {
                type = "gpt";
                partitions = {
                  ESP = {
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                      mountOptions = [ "umask=0077" ];
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

#### Example for a NixOS installer

```nix
# `self` here is referring to the flake `self`, you may need to pass it using `specialArgs` or define your NixOS installer configuration
# in the flake.nix itself to get direct access to the `self` flake variable.
{ pkgs, self, ... }:
let
  dependencies = [
    self.nixosConfigurations.your-machine.config.system.build.toplevel
    self.nixosConfigurations.your-machine.config.system.build.diskoScript
    self.nixosConfigurations.your-machine.config.system.build.diskoScript.drvPath
    self.nixosConfigurations.your-machine.pkgs.stdenv.drvPath
    (self.nixosConfigurations.your-machine.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
  ] ++ builtins.map (i: i.outPath) (builtins.attrValues self.inputs);

  closureInfo = pkgs.closureInfo { rootPaths = dependencies; };
in
# Now add `closureInfo` to your NixOS installer
{
  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "install-nixos-unattended" ''
      set -eux
      # Replace "/dev/disk/by-id/some-disk-id" with your actual disk ID
      exec ${pkgs.disko}/bin/disko-install --flake "${self}#your-machine" --disk vdb "/dev/disk/by-id/some-disk-id"
    '')
  ];
}
```

Also see the
[NixOS test of disko-install](https://github.com/nix-community/disko/blob/master/tests/disko-install/default.nix)
that also runs without internet.
