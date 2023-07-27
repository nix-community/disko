{ nixosConfig
, diskoLib
, pkgs ? nixosConfig.pkgs
, lib ? pkgs.lib
, name ? "${nixosConfig.config.networking.hostName}-disko-images"
}:
let
  cleanedConfig = diskoLib.testLib.prepareDiskoConfig nixosConfig.config diskoLib.testLib.devices;
  systemToInstall = nixosConfig.extendModules {
    modules = [{
      disko.devices = lib.mkForce cleanedConfig.disko.devices;
      boot.loader.grub.devices = lib.mkForce cleanedConfig.boot.loader.grub.devices;
    }];
  };
in
pkgs.vmTools.runInLinuxVM (pkgs.runCommand name {
  buildInputs = with pkgs; [
    systemdMinimal
    nixos-install-tools
    nix
    utillinux
  ];
  preVM = ''
    # TODO: get size either dynamically or from disko config
    ${lib.concatMapStringsSep "\n" (disk: "truncate -s 15G ${disk.name}.raw") (lib.attrValues nixosConfig.config.disko.devices.disk)}
  '';
  postVM = ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (disk: "cp ${disk.name}.raw $out/${disk.name}.raw") (lib.attrValues nixosConfig.config.disko.devices.disk)}
  '';
  QEMU_OPTS = lib.concatMapStringsSep " " (disk: "-drive file=${disk.name}.raw,if=virtio,cache=unsafe,werror=report") (lib.attrValues nixosConfig.config.disko.devices.disk);

  memSize = 1024;
} ''
  # running udev, stolen from stage-1.sh
  echo "running udev..."
  ln -sfn /proc/self/fd /dev/fd
  ln -sfn /proc/self/fd/0 /dev/stdin
  ln -sfn /proc/self/fd/1 /dev/stdout
  ln -sfn /proc/self/fd/2 /dev/stderr
  mkdir -p /etc/udev
  ln -sfn ${systemToInstall.config.system.build.etc}/etc/udev/rules.d /etc/udev/rules.d
  mkdir -p /dev/.mdadm
  ${pkgs.systemdMinimal}/lib/systemd/systemd-udevd --daemon
  udevadm trigger --action=add
  udevadm settle

  # populate nix db, so nixos-install doesn't complain
  export NIX_STATE_DIR=$TMPDIR/state
  nix-store --load-db < ${pkgs.closureInfo {
    rootPaths = [ systemToInstall.config.system.build.toplevel ];
  }}/registration

  ${systemToInstall.config.system.build.diskoScript}
  ${pkgs.nixos-install-tools}/bin/nixos-install --system ${systemToInstall.config.system.build.toplevel} --keep-going --no-channel-copy -v --no-root-password --option binary-caches ""
'')
