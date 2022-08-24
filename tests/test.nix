{ makeTest ? import <nixpkgs/nixos/tests/make-test-python.nix>
, pkgs ? (import <nixpkgs> {})
}:
let
  makeTest' = args:
    makeTest args {
      inherit pkgs;
      inherit (pkgs) system;
    };
  disko-config = import ../example/raid.nix;
  wrapScript = pkgs: script:
    let
      diskoEnv = pkgs.symlinkJoin {
        name = "diskoEnv";
        paths = with pkgs;[
          # Device and partition tools
          cryptsetup
          lvm2.bin
          mdadm
          parted

          # Packages that provide a mkfs.* binary
          btrfs-progs
          dosfstools
          e2fsprogs
          f2fs-tools
          nilfs-utils
          util-linux
          xfsprogs
        ];
      } ;
    in pkgs.writeScript "wrapped" ''
      #!${pkgs.bash}/bin/bash
      export PATH=${diskoEnv}/bin:$PATH
      ${script}
    '';
  tsp-create = pkgs.writeScript "create" ((pkgs.callPackage ../. {}).create disko-config);
  tsp-mount = pkgs.writeScript "mount" ((pkgs.callPackage ../. {}).mount disko-config);
  baseConfig =
    { modulesPath, ... }:

    {
      imports = [
        (modulesPath + "/profiles/installation-device.nix")
        (modulesPath + "/profiles/base.nix")
      ];

      # speed-up eval
      documentation.enable = false;

      virtualisation.diskSize = 512;
      virtualisation.emptyDiskImages = [ 32 32 ];
    };
in makeTest' {
  name = "disko";

  nodes.manual1 = baseConfig;

  nodes.automatic1 = {pkgs, modulesPath, ...}: {
    imports = [
      baseConfig
      (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ];
    systemd.services.install-to-hd = {
      enable = true;
      wantedBy = ["multi-user.target"];
      after = ["getty@tty1.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          (wrapScript pkgs tsp-create)
          (wrapScript pkgs tsp-mount)
        ];
        StandardInput = "null";
        StandardOutput = "journal+console";
        StandardError = "inherit";
      };
    };
  };

  testScript = ''
    EXPECTED_BLKS = """
    vda 253:0 0 512M 0 disk /
    vdb 253:16 0 32M 0 disk
    vdb1 253:17 0 31M 0 part
    md127 9:127 0 29.9M 0 raid1
    md127p1 259:0 0 28.9M 0 part
    vdc 253:32 0 32M 0 disk
    vdc1 253:33 0 31M 0 part
    md127 9:127 0 29.9M 0 raid1
    md127p1 259:0 0 28.9M 0 part
    """

    start_all()

    manual1.succeed("${tsp-create}");
    manual1.succeed("${tsp-mount}");
    manual1.succeed("${tsp-mount}"); # verify that the command is idempotent

    for node in [manual1, automatic1]:
      node.wait_for_file("/mnt/raid")
      node.succeed("test -b /dev/md/raid1")

      blks = node.succeed("lsblk --raw")
      print(blks)
      for line in EXPECTED_BLKS.strip().splitlines():
        assert line in blks, f"Line not found: {line}"
  '';
}
