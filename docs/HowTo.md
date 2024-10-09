# How-to Guide: Disko

## How to use Disko without NixOS

TODO: Still to be documented

## Upgrading From Older disko versions

TODO: Include documentation here.

For now, see the
[upgrade guide](https://github.com/JillThornhill/disko/blob/master/docs/upgrade-guide.md)

## Installing NixOS module

You can use the NixOS module in one of the following ways:

<details>
  <summary>Flakes (Current recommendation)</summary>

If you use nix flakes support:

```nix
{
  inputs.disko.url = "github:nix-community/disko/latest";
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
niv add nix-community/disko
```

Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ "${(import ./nix/sources.nix).disko}/module.nix" ];
}
```

</details>
<details>
  <summary>npins</summary>

First add it to [npins](https://github.com/andir/npins):

```console
npins add github nix-community disko
```

Then add the following to your configuration.nix in the `imports` list:

```nix
let
  sources = import ./npins;
  disko = import sources.disko {};
in
{
  imports = [ "${disko}/module.nix" ];
  …
}
```

</details>
<details>
  <summary>nix-channel</summary>

As root run:

```console
nix-channel --add https://github.com/nix-community/disko/archive/master.tar.gz disko
nix-channel --update
```

Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ <disko/module.nix> ];
}
```

</details>
<details>
  <summary>fetchTarball</summary>

Add the following to your configuration.nix:

```nix
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
    disk = {
      vdb = {
        device = "/dev/disk/by-id/some-disk-id";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "100M";
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
```

this will configure `fileSystems` and other required NixOS options to boot the
specified configuration.

If you are on an installer, you probably want to disable `enableConfig`.

disko will create the scripts `disko-create` and `disko-mount` which can be used
to create/mount the configured disk layout.
