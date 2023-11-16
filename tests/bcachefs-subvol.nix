{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-subvol";
  disko-config = ../example/bcachefs-subvol.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk >&2");
    machine.succeed("ls /");
  '';
  # so that the installer boots with a bcachefs enabled kernel
  extraInstallerConfig = {
    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [
      (_final: super: {
        zfs = super.zfs.overrideAttrs (_: {
          meta.platforms = [ ];
        });
      })
    ];
    boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_testing;
  };
  extraSystemConfig = {
    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [
      (_final: super: {
        zfs = super.zfs.overrideAttrs (_: {
          meta.platforms = [ ];
        });
      })
    ];
    boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_testing;
  };

}
