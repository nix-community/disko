{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "f2fs";
  disko-config = ../example/f2fs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk --fs >&2");
  '';
  # so that the installer boots with a f2fs enabled kernel
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "f2fs" ];
  };
}
