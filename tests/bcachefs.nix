{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs";
  disko-config = ../example/bcachefs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk >&2");
  '';
  # so that the installer boots with a bcachefs enabled kernel
  extraInstallerConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [
      (_final: super: {
        zfs = super.zfs.overrideAttrs (_: {
          meta.platforms = [ ];
        });
      })
    ];
  };
}
