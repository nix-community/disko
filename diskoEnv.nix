{ pkgs ? import <nixpkgs> {} }:
  pkgs.symlinkJoin {
    name = "diskoEnv";
    paths = with pkgs;[
      bash

      # Device and partition tools
      cryptsetup
      lvm2.bin
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
  }