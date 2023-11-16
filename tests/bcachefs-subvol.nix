{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
}:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "bcachefs-subvol";

  disko-config = ../example/bcachefs-subvol.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk >&2");
    machine.succeed("ls /");

    # there is no subcommand for checking a subvolume, but only subvolumes can be snapshotted
    machine.succeed("bcachefs subvolume snapshot /home /home.snap");
    machine.succeed("bcachefs subvolume snapshot /nix /nix.snap");
    machine.succeed("bcachefs subvolume snapshot /testpath /testpath.snap");
    machine.succeed("bcachefs subvolume snapshot /testpath/subdir /testpath/subdir.snap");
    # ensure this behavior doesn't change
    machine.succeed("ls /srv");
    machine.fail("bcachefs subvolume snapshot /srv /srv.snap"); 
  '';

  # so that the installer boots with a bcachefs enabled kernel
  extraInstallerConfig = {
    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [
      (_final: super: { zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; }); })
    ];
    boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_testing;
  };

  extraSystemConfig = {
    environment.systemPackages = [ pkgs.bcachefs-tools ];

    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [
      (_final: super: { zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; }); })
    ];
    boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_testing;
  };
}
