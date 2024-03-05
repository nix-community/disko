{ nixosConfig
, diskoLib
, pkgs ? nixosConfig.pkgs
, lib ? pkgs.lib
, name ? "${nixosConfig.config.networking.hostName}-disko-images"
, extraPostVM ? ""
, checked ? false
}:
let
  vmTools = pkgs.vmTools.override {
    rootModules = ["9p" "9pnet_virtio" "virtio_pci" "virtio_blk"] ++ nixosConfig.config.disko.extraRootModules;
    kernel = pkgs.aggregateModules
    (with nixosConfig.config.boot.kernelPackages; [ kernel ]
      ++ lib.optional (lib.elem "zfs" nixosConfig.config.disko.extraRootModules) zfs);
  };
  cleanedConfig = diskoLib.testLib.prepareDiskoConfig nixosConfig.config diskoLib.testLib.devices;
  systemToInstall = nixosConfig.extendModules {
    modules = [{
      disko.devices = lib.mkForce cleanedConfig.disko.devices;
      boot.loader.grub.devices = lib.mkForce cleanedConfig.boot.loader.grub.devices;
    }];
  };
  dependencies = with pkgs; [
    bash
    iproute
    coreutils
    gnused
    parted # for partprobe
    systemdMinimal
    nix
    util-linux
  ] ++ nixosConfig.config.disko.extraDependencies;
  preVM = ''
    ${lib.concatMapStringsSep "\n" (disk: "truncate -s ${disk.imageSize} ${disk.name}.raw") (lib.attrValues nixosConfig.config.disko.devices.disk)}
  '';
  postVM = ''
    # shellcheck disable=SC2154
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (disk: "mv ${disk.name}.raw \"$out\"/${disk.name}.raw") (lib.attrValues nixosConfig.config.disko.devices.disk)}
    ${extraPostVM}
  '';
  partitioner = ''
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
    partprobe
    udevadm trigger --action=add
    udevadm settle

    # populate nix db, so nixos-install doesn't complain
    export NIX_STATE_DIR=$TMPDIR/state
    nix-store --load-db < ${pkgs.closureInfo {
      rootPaths = [ systemToInstall.config.system.build.toplevel ];
    }}/registration

    # configure user network
    echo $(${pkgs.iproute}/bin/ip link)
    ${pkgs.iproute}/bin/ip link set dev ens3 up
    ${pkgs.iproute}/bin/ip addr add 10.0.2.15/24 dev ens3
    ${pkgs.iproute}/bin/ip route add default via 10.0.2.2
    echo 'nameserver 10.0.2.3' > /etc/resolv.conf

    ${systemToInstall.config.system.build.diskoScript}
  '';
  installer = ''
    ${systemToInstall.config.system.build.nixos-install}/bin/nixos-install --system ${systemToInstall.config.system.build.toplevel} --keep-going --no-channel-copy -v --no-root-password --option binary-caches ""
    umount -Rv ${systemToInstall.config.disko.rootMountPoint}
  '';
  QEMU_OPTS = lib.concatMapStringsSep " " (disk: "-drive file=${disk.name}.raw,if=virtio,cache=unsafe,werror=report,format=raw") (lib.attrValues nixosConfig.config.disko.devices.disk);
in
{
  pure = vmTools.runInLinuxVM (pkgs.runCommand name
    {
      buildInputs = dependencies;
      inherit preVM postVM QEMU_OPTS;
      memSize = nixosConfig.config.disko.memSize;
    }
    (partitioner + installer));
  impure = diskoLib.writeCheckedBash { inherit checked pkgs; } name ''
    set -efu
    export PATH=${lib.makeBinPath dependencies}
    showUsage() {
    cat <<\USAGE
    Usage: $script [options]

    Options:
    * --pre-format-files <src> <dst>
      copies the src to the dst on the VM, before disko is run
      This is useful to provide secrets like LUKS keys, or other files you need for formating
    * --post-format-files <src> <dst>
      copies the src to the dst on the finished image
      These end up in the images later and is useful if you want to add some extra stateful files
      They will have the same permissions but will be owned by root:root
    * --build-memory <amt>
      specify the ammount of memory that gets allocated to the build vm (in mb)
      This can be usefull if you want to build images with a more involed NixOS config
      By default the vm will get 1024M/1GB
    USAGE
    }

    export out=$PWD
    TMPDIR=$(mktemp -d); export TMPDIR
    trap 'rm -rf "$TMPDIR"' EXIT
    cd "$TMPDIR"

    mkdir copy_before_disko copy_after_disko

    while [[ $# -gt 0 ]]; do
      case "$1" in
      --pre-format-files)
        src=$2
        dst=$3
        cp --reflink=auto -r "$src" copy_before_disko/"$(echo "$dst" | base64)"
        shift 2
        ;;
      --post-format-files)
        src=$2
        dst=$3
        cp --reflink=auto -r "$src" copy_after_disko/"$(echo "$dst" | base64)"
        shift 2
        ;;
      --build-memory)
        regex="^[0-9]+$"
        if ! [[ $2 =~ $regex ]]; then
          echo "'$2' is not a number"
          exit 1
        fi
        build_memory=$2
        shift 1
        ;;
      *)
        showUsage
        exit 1
        ;;
      esac
      shift
    done

    export preVM=${diskoLib.writeCheckedBash { inherit pkgs checked; } "preVM.sh" ''
      set -efu
      mv copy_before_disko copy_after_disko xchg/
      ${preVM}
    ''}
    export postVM=${diskoLib.writeCheckedBash { inherit pkgs checked; } "postVM.sh" postVM}
    export origBuilder=${pkgs.writeScript "disko-builder" ''
      set -eu
      export PATH=${lib.makeBinPath dependencies}
      for src in /tmp/xchg/copy_before_disko/*; do
        [ -e "$src" ] || continue
        dst=$(basename "$src" | base64 -d)
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
      done
      set -f
      ${partitioner}
      set +f
      for src in /tmp/xchg/copy_after_disko/*; do
        [ -e "$src" ] || continue
        dst=/mnt/$(basename "$src" | base64 -d)
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
      done
      ${installer}
    ''}

    build_memory=''${build_memory:-1024}
    QEMU_OPTS=${lib.escapeShellArg QEMU_OPTS}
    QEMU_OPTS+=" -m $build_memory"
    export QEMU_OPTS

    ${pkgs.bash}/bin/sh -e ${vmTools.vmRunCommand vmTools.qemuCommandLinux}
    cd /
  '';
}
