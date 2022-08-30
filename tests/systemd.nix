{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest rec {
  disko-config = import ../example/config-gpt-bios.nix;
  extraConfig.systemd.services.install-to-hd = {
    enable = true;
    wantedBy = ["multi-user.target"];
    after = ["getty@tty1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        (pkgs.writeShellScript "create" ((pkgs.callPackage ../. { }).create disko-config))
        (pkgs.writeShellScript "mount" ((pkgs.callPackage ../. { }).mount disko-config))
      ];
      StandardInput = "null";
      StandardOutput = "journal+console";
      StandardError = "inherit";
    };
  };
  extraTestScript = ''
    import json

    expected = {
      "blockdevices": [
        {
          "name": "vdb",
          "maj:min": "253:16",
          "rm": False,
          "size": "512M",
          "ro": False,
          "type": "disk",
          "mountpoints": [None],
          "children": [
            {
              "name": "vdb1",
              "maj:min": "253:17",
              "rm": False,
              "size": "960K",
              "ro": False,
              "type": "part",
              "mountpoints": [None]
            },
            {
              "name": "vdb2",
              "maj:min": "253:18",
              "rm": False,
              "size": "510M",
              "ro": False,
              "type": "part",
              "mountpoints": ["/mnt"]
            }
          ]
        }
      ]
    }
    blks = json.loads(machine.succeed("lsblk --json /dev/vdb"))
    assert blks == expected, f"Unexpected layout:\n{blks}"
  '';
}
