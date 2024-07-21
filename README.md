# disko - Declarative disk partitioning

<!-- Generated with bing image generator (which uses dall-e-2): edge-gpt-image --prompt "Disco ball shooting a laser beam at one hard drive" -->

<img title="" src="./docs/logo.jpeg" alt="Project logo" width="274">

[Documentation Index](./docs/INDEX.md)

NixOS is a Linux distribution where everything is described as code, with one
exception: during installation, the disk partitioning and formatting are manual
steps. **disko** aims to correct this sad 🤡 omission.

This is especially useful for unattended installations, re-installation after a
system crash or for setting up more than one identical server.

## Overview

**disko** can either be used after booting from a NixOS installer, or in
conjunction with [nixos-anywhere](https://github.com/numtide/nixos-anywhere) if
you're installing remotely.

Before using **disko**, the specifications of the disks, partitions, type of
formatting and the mount points must be defined in a Nix configuration. You can
find [examples](./example) of typical configurations in the Nix community
repository, and use one of these as the basis of your own configuration.

You can keep your configuration and re-use it for other installations, or for a
system rebuild.

**disko** is flexible, in that it supports most of the common formatting and
partitioning options, including:

- Disk layouts: GPT, MBR, and mixed.
- Partition tools: LVM, mdadm, LUKS, and more.
- Filesystems: ext4, btrfs, ZFS, bcachefs, tmpfs, and others.

It can work with these in various configurations and orders, and supports
recursive layouts.

## How to use disko

Disko doesn't require installation: it can be run directly from nix-community
repository. The [Quickstart Guide](./docs/quickstart.md) documents how to run
Disko in its simplest form when installing NixOS. Alternatively, you can also
use the new [disko-install](./docs/disko-install.md) tool, which combines the
`disko` and `nixos-install` into one step.

For information on other use cases, including upgrading from an older version of
**disko**, using **disko** without NixOS and downloading the module, see the
[How To Guide](./docs/HowTo.md)

For more detailed options, such as command line switches, see the
[Reference Guide](./docs/reference.md)

To access sample configurations for commonly-used disk layouts, refer to the
[examples](./example) provided.

Disko can be also used to create [disk images](./docs/disko-images.md).

## Sample Configuration and CLI command

A simple disko configuration may look like this:

```nix
{
  disko.devices = {
    disk = {
      my-disk = {
        device = "/dev/sda";
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
```

If you'd saved this configuration in /tmp/disk-config.nix, and wanted to create
a disk named /dev/sda, you would run the following command to partition, format
and mount the disk.

```console
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /tmp/disk-config.nix
```

## Related Tools

This tool is used by
[nixos-anywhere](https://github.com/numtide/nixos-anywhere), which carries out a
fully-automated remote install of NixOS.

We also acknowledge https://github.com/NixOS/nixpart, the conceptual ancestor of
this project.

## Licensing and Contribution details

This software is provided free under the
[MIT Licence](https://opensource.org/licenses/MIT).

## Get in touch

We have a public matrix channel at
[disko](https://matrix.to/#/#disko:nixos.org).

---

This project is supported by [Numtide](https://numtide.com/).
![Untitledpng](https://codahosted.io/docs/6FCIMTRM0p/blobs/bl-sgSunaXYWX/077f3f9d7d76d6a228a937afa0658292584dedb5b852a8ca370b6c61dabb7872b7f617e603f1793928dc5410c74b3e77af21a89e435fa71a681a868d21fd1f599dd10a647dd855e14043979f1df7956f67c3260c0442e24b34662307204b83ea34de929d)

We are a team of independent freelancers that love open source.  We help our
customers make their project lifecycles more efficient by:

- Providing and supporting useful tools such as this one
- Building and deploying infrastructure, and offering dedicated DevOps support
- Building their in-house Nix skills, and integrating Nix with their workflows
- Developing additional features and tools
- Carrying out custom research and development.

[Contact us](https://numtide.com/contact) if you have a project in mind, or if
you need help with any of our supported tools, including this one. We'd love to
hear from you.
