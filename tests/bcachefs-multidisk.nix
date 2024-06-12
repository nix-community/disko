{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-multidisk";
  disko-config = ../example/bcachefs-multidisk.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk >&2");
  '';
  # so that the installer boots with a bcachefs enabled kernel
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
