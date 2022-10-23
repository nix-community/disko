# disko

nix-powered automatic disk partitioning.  partition your disks declaratively NixOS style.

## Installing NixOS module

You can use the NixOS module in one of the following ways:

### Flakes

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

### [niv](https://github.com/nmattia/niv) (Current recommendation)
  First add it to niv:

```console
$ niv add nix-community/disko
```

  Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ "${(import ./nix/sources.nix).disko}/modules/disko.nix" ];
}
```

### nix-channel

  As root run:

```console
$ nix-channel --add https://github.com/nix-community/disko/archive/main.tar.gz disko
$ nix-channel --update
```

  Then add the following to your configuration.nix in the `imports` list:

```nix
{
  imports = [ <disko/modules/disko.nix> ];
}
```

### fetchTarball

  Add the following to your configuration.nix:

``` nix
{
  imports = [ "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/main.tar.gz"}/modules/disko.nix" ];
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

## Using the NixOS module

```nix
{
  # checkout the example folder for how to configure different diska layouts
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
