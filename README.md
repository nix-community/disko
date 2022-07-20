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
  disko = import (builtins.fetchGit {
    url = https://github.com/nix-community/disko;
    rev = "22b87e5c0a6fc32bb75f91f4465ba9651c2c13ca";
  }) {};
  cfg = builtins.fromJSON ./tsp-disk.json;
  create = pkgs.writeScript "tsp-create" (disko.create cfg);
  mount = pkgs.writeScript "tsp-mount" (disko.mount cfg);
in {
  environment.systemPackages = with pkgs; [create mount];
  ## Optional: Automatically creates a service which runs at startup to perform the partitioning
  #systemd.services.install-to-hd = {
  #  enable = true;
  #  wantedBy = ["multi-user.target"];
  #  after = ["getty@tty1.service" ];
  #  serviceConfig = {
  #    Type = "oneshot";
  #    ExecStart = [ create mount ];
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
