# disko - declarative disk partitioning

Disko takes the NixOS module system and makes it work for disk partitioning
as well.

I wanted to write a curses NixOS installer, and that was the first step that I
hit; the disk formatting is a manual process. Once that's done, the NixOS
system itself is declarative, but the actual formatting of disks is manual.

## Features

* supports LVM, ZFS, btrfs, GPT, mdadm, ext4, ...
* supports recursive layouts
* outputs a NixOS-compatible module
* CLI

## How-to guides

### NixOS installation

For a NixOS installation follow this [quickstart guide](./docs/quickstart.md).

### Using without NixOS

## Reference

### Module options

TODO: link to generated module options

### Examples

./examples

### CLI

```
$ nix run github:nix-community/disko --

disko [options] disk-config.nix
or disko [options] --flake github:somebody/somewhere

Options:

* -m, --mode mode
  set the mode, either create or mount
* -f, --flake uri
  fetch the disko config relative to this flake's root
* --arg name value
  pass value to nix-build. can be used to set disk-names for example
* --argstr name value
  pass value to nix-build as string
* --root-mountpoint /mnt
  where to mount the device tree
* --dry-run
  just show the path to the script instead of running it
* --debug
  run with set -x

```



## Installing NixOS module

You can use the NixOS module in one of the following ways:

<details>
  <summary>Flakes (Current recommendation)</summary>

If you use nix flakes support:

``` nix
{
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, disko }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      # change to your system:
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        disko.nixosModules.disko
      ];
    };
  };
}
```
</details>
<details>
  <summary>niv</summary>
  
  First add it to [niv](https://github.com/nmattia/niv):

```console
$ niv add nix-community/disko
```

  Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ "${(import ./nix/sources.nix).disko}/modules/disko.nix" ];
}
```
</details>
<details>
  <summary>nix-channel</summary>

  As root run:

```console
$ nix-channel --add https://github.com/nix-community/disko/archive/master.tar.gz disko
$ nix-channel --update
```

  Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ <disko/modules/disko.nix> ];
}
```
</details>
<details>
  <summary>fetchTarball</summary>

  Add the following to your configuration.nix:

``` nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix" ];
}
```

  or with pinning:

```nix
{
  imports = let
    # replace this with an actual commit id or tag
    commit = "f2783a8ef91624b375a3cf665c3af4ac60b7c278";
  in [ 
    "${builtins.fetchTarball {
      url = "https://github.com/nix-community/disko/archive/${commit}.tar.gz";
      # replace this with an actual hash
      sha256 = "0000000000000000000000000000000000000000000000000000";
    }}/module.nix"
  ];
}
```
</details>

## Using the NixOS module

```nix
{
  # checkout the example folder for how to configure different disko layouts
  disko.devices = {
    disk.sda = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            name = "ESP";
            start = "1MiB";
            end = "100MiB";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            name = "root";
            type = "partition";
            start = "100MiB";
            end = "100%";
            part-type = "primary";
            bootable = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          }
        ];
      };
    };
  };
}
```

this will configure `fileSystems` and other required NixOS options to boot the specified configuration.

If you are on an installer, you probably want to disable `enableConfig`.

disko will create the scripts `disko-create` and `disko-mount` which can be used to create/mount the configured disk layout.
