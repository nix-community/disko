{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/testing/test-instrumentation.nix"
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  boot.supportedFilesystems = [
    "btrfs"
    "cifs"
    "f2fs"
    "jfs"
    "ntfs"
    "reiserfs"
    "vfat"
    "xfs"
  ]
  ++ lib.optional (
    config.networking.hostId != null
    && lib.meta.availableOn pkgs.stdenv.hostPlatform config.boot.zfs.package
  ) "zfs";

  boot.swraid.enable = true;
  # silence warning about unset mail
  boot.swraid.mdadmConf = "PROGRAM ${pkgs.coreutils}/bin/true";

  systemd.services.mdmonitor.enable = false; # silence some weird warnings

  environment.systemPackages = [
    pkgs.jq
  ];

  # speed-up eval
  documentation.enable = false;

  nix.settings = {
    substituters = lib.mkForce [ ];
    hashed-mirrors = null;
    connect-timeout = 1;
  };
}
