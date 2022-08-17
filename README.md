disko
=====

nix-powered automatic disk partitioning

Usage
=====

Master Boot Record
------------------
This is how your iso configuation may look like

/etc/nixos/configuration.nix
```nix
{ pkgs, modulesPath, ... }:
let
  disko = pkgs.callPackage (builtins.fetchGit {
    url = "https://github.com/nix-community/disko";
    ref = "master";
  }) {};
  cfg = {
    type = "devices";
    content = {
      sda = {
        type = "table";
        format = "msdos";
        partitions = [{
          type = "partition";
          part-type = "primary";
          start = "1M";
          end = "100%";
          bootable = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }];
      };
    };
  };
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];
  environment.systemPackages = with pkgs;[
    (pkgs.writeScriptBin "tsp-create" (disko.create cfg))
    (pkgs.writeScriptBin "tsp-mount" (disko.mount cfg))
  ];
  ## Optional: Automatically creates a service which runs at startup to perform the partitioning
  #systemd.services.install-to-hd = {
  #  enable = true;
  #  wantedBy = ["multi-user.target"];
  #  after = ["getty@tty1.service" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    ExecStart = [ (disko.create cfg) (disk.mount cfg) ];
  #    StandardInput = "null";
  #    StandardOutput = "journal+console";
  #    StandardError = "inherit";
  #  };
  #};
}
```

After `nixos-rebuild switch` this will add a `tsp-create` and a `tsp-mount`
command:

- **tsp-create**: creates & formats the partitions according to `tsp-disk.json`
- **tsp-mount**: mounts the partitions to `/mnt`

GUID Partition Table, LVM and dm-crypt
--------------------------------------
See `examples/`
