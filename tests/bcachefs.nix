{ pkgs ? (import <nixpkgs> { })
, makeDiskoTest ? (pkgs.callPackage ./lib.nix { }).makeDiskoTest
}:
makeDiskoTest {
  disko-config = ../example/bcachefs.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /");
    machine.succeed("lsblk >&2");
  '';
  # so that the installer boots with a bcachefs enabled kernel
  extraConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
    # disable zfs so we can support latest kernel
    nixpkgs.overlays = [(final: super: {
      zfs = super.zfs.overrideAttrs(_: {meta.platforms = [];});}
    )];
  };
}
