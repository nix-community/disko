disko
=====

nix-powered automatic disk partitioning

Usage
=====

Master Boot Record
------------------
This is how your iso configuation may look like

/etc/nixos/tsp-disk.json (TODO: find the correct disk)
```json
{
  "type": "devices",
  "content": {
    "sda": {
      "type": "table",
      "format": "msdos",
      "partitions": [{
        "type": "partition",
        "start": "1M",
        "end": "100%",
        "bootable": true,
        "content": {
          "type": "filesystem",
          "format": "ext4",
          "mountpoint": "/"
        }
      }]
    }
  }
}
```

/etc/nixos/configuration.nix
```nix
{ pkgs, ... }:
let
  disko = (builtins.fetchGit {
    url = https://cgit.lassul.us/disko/;
    rev = "88f56a0b644dd7bfa8438409bea5377adef6aef4";
  }) + "/lib";
  cfg = builtins.fromJSON ./tsp-disk.json;
in {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
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
