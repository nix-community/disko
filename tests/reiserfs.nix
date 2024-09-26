{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "reiserfs";
  disko-config = ../example/reiserfs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk --fs >&2");
  '';
  # so that the installer boots with a reiserfs enabled kernel
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "reiserfs" ];
  };
}
