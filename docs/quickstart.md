# Disko quickstart

This tutorial will guide you through the process of installing NixOS on a single
disk system using Disko.

1. Booting the installer

Download NixOS ISO images from the NixOS download page
(https://nixos.org/download.html#nixos-iso) and create a bootable USB drive
following the instructions in [Section 2.4.1 "Booting from a USB flash drive"](https://nixos.org/manual/nixos/stable/index.html#sec-booting-from-usb)
of the NixOS manual.

2. The disk name

Identify the name of your system disk by using the lsblk command.

```
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0   1,8T  0 disk
```

In this example, an empty NVME SSD with 2TB space is shown as "nvme0n1" disk.
Please note that Disko will reformat the entire disk and overwrite any existing
partitions. Dual booting with other operating systems is not supported.


3. Disk layout

Choose a disk layout from the [examples directory](https://github.com/nix-community/disko/tree/master/example)

For those who are unsure of which layout to pick, use the hybrid configuration
found at https://github.com/nix-community/disko/blob/master/example/hybrid.nix
and save it as `/tmp/disko-config.nix`. This layout is compatible with both BIOS
and EFI systems.

4. Formatting

The following step will reformat your disk and mount it to `/mnt`. Replace `<disk-name>` with the name of your disk obtained in step 1.

Please note: This will erase any existing data on your disk.

```
$ sudo nix run github:nix-community/disko -- --mode zap_create_mount /tmp/disko-config.nix --arg disks '[ "/dev/<disk-name>" ]'
```

For example, if the disk name is `nvme0n1`:

```
$ sudo nix run github:nix-community/disko -- --mode zap_create_mount /tmp/disko-config.nix --arg disks '[ "/dev/nvme0n1" ]'
```


After executing the command, the file systems will be mounted. You can verify
this by running the following command:

```
$ mount | grep /mnt
/dev/nvme0n1p1 on /mnt type ext4 (rw,relatime,stripe=2)
/dev/nvme0n1p2 on /mnt/boot type vfat (rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
```

5. Rest of the NixOS installation:

Generate and modify the NixOS configuration.

You now need to create a file `/mnt/etc/nixos/configuration.nix` that specifies
the intended configuration of the system. This is because NixOS has a
declarative configuration model: you create or edit a description of the desired
configuration of your system, and then NixOS takes care of making it happen. The
syntax of the NixOS configuration file is described in
[Chapter 6, Configuration Syntax](https://nixos.org/manual/nixos/stable/index.html#sec-configuration-syntax),
while a list of available configuration options appears in
[Appendix A, Configuration Options](https://nixos.org/manual/nixos/stable/options.html).
A minimal example is shown in
[Example: NixOS Configuration](https://nixos.org/manual/nixos/stable/index.html#ex-config).

The command nixos-generate-config can generate an initial configuration file for
you.

```
$ nixos-generate-config --no-filesystems --root /mnt
```

We will include `--no-filesystems` the flag here so it won't add any filesystem
mountpoints to the generated `/mnt/etc/nixos/hardware-configuration.nix` since
we will re-use our disko configuration for that.

Next move the disko configuration as well to /etc/nixos

```
$ mv /tmp/disko-config.nix /mnt/etc/nixos
```

You should then edit /mnt/etc/nixos/configuration.nix to suit your needs

```
$ nano /mnt/etc/nixos/configuration.nix
```

While being in this file also add the disko nixos module as well as the
disko-config.nix in the imports section of your generated configuration:

```
imports =
 [ # Include the results of the hardware scan.
   ./hardware-configuration.nix
   "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
   (import ./disko-config.nix {
     disks = [ "/dev/<disk-name>" ]; # replace this with your disk name i.e. /dev/nvme0n1
   })
 ];
```

If you went for the hybrid-partition scheme, than choose grub as a bootloader.
Otherwise consult the NixOS manual. The following configuration for Grub works
both EFI and BIOS systems. Add it to your configuration.nix while commenting out
the existing lines about `systemd-boot`:

```
# ...
   #boot.loader.systemd-boot.enable = true;
   #boot.loader.efi.canTouchEfiVariables = true;
   # replace this with your disk i.e. /dev/nvme0n1
   boot.loader.grub.devices = [ "/dev/<disk-name>" ];
   boot.loader.grub.enable = true;
   boot.loader.grub.version = 2;
   boot.loader.grub.efiSupport = true;
   boot.loader.grub.efiInstallAsRemovable = true;
# ...
```

Than finish the installation and reboot your machine

```
$ nixos-install
$ reboot
```
