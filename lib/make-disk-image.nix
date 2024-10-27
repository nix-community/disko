{ config
, diskoLib
, lib
, extendModules
, options
, ...
}:
let
  diskoCfg = config.disko;
  cfg = diskoCfg.imageBuilder;
  inherit (cfg) pkgs imageFormat;
  checked = diskoCfg.checkScripts;

  configSupportsZfs = config.boot.supportedFilesystems.zfs or false;
  vmTools = pkgs.vmTools.override
    {
      rootModules = [ "9p" "9pnet_virtio" "virtio_pci" "virtio_blk" ]
        ++ (lib.optional configSupportsZfs "zfs")
        ++ cfg.extraRootModules;
      kernel = pkgs.aggregateModules
        (with cfg.kernelPackages; [ kernel ]
          ++ lib.optional (lib.elem "zfs" cfg.extraRootModules || configSupportsZfs) zfs);
    }
  // lib.optionalAttrs (diskoLib.vmToolsSupportsCustomQemu pkgs)
    {
      customQemu = cfg.qemu;
    };
  cleanedConfig = diskoLib.testLib.prepareDiskoConfig config diskoLib.testLib.devices;
  systemToInstall = extendModules {
    modules = [
      cfg.extraConfig
      {
        disko.testMode = true;
        disko.devices = lib.mkForce cleanedConfig.disko.devices;
        boot.loader.grub.devices = lib.mkForce cleanedConfig.boot.loader.grub.devices;
      }
    ];
  };
  dependencies = with pkgs; [
    bash
    coreutils
    gnused
    parted # for partprobe
    systemdMinimal
    nix
    util-linux
    findutils
  ] ++ cfg.extraDependencies;
  preVM = ''
    ${lib.concatMapStringsSep "\n" (disk: "${pkgs.qemu}/bin/qemu-img create -f ${imageFormat} ${disk.imageName}.${imageFormat} ${disk.imageSize}") (lib.attrValues diskoCfg.devices.disk)}
    # This makes disko work, when canTouchEfiVariables is set to true.
    # Technically these boot entries will no be persisted this way, but
    # in most cases this is OK, because we can rely on the standard location for UEFI executables.
    install -m600 ${pkgs.OVMF.variables} efivars.fd
  '';
  postVM = ''
    # shellcheck disable=SC2154
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (disk: "mv ${disk.imageName}.${imageFormat} \"$out\"/${disk.imageName}.${imageFormat}") (lib.attrValues diskoCfg.devices.disk)}
    ${cfg.extraPostVM}
  '';

  closureInfo = pkgs.closureInfo {
    rootPaths = [ systemToInstall.config.system.build.toplevel ];
  };
  partitioner = ''
    set -efux
    # running udev, stolen from stage-1.sh
    echo "running udev..."
    ln -sfn /proc/self/fd /dev/fd
    ln -sfn /proc/self/fd/0 /dev/stdin
    ln -sfn /proc/self/fd/1 /dev/stdout
    ln -sfn /proc/self/fd/2 /dev/stderr
    mkdir -p /etc/udev
    mount -t efivarfs none /sys/firmware/efi/efivars
    ln -sfn ${systemToInstall.config.system.build.etc}/etc/udev/rules.d /etc/udev/rules.d
    mkdir -p /dev/.mdadm
    ${pkgs.systemdMinimal}/lib/systemd/systemd-udevd --daemon
    partprobe
    udevadm trigger --action=add
    udevadm settle

    ${lib.optionalString diskoCfg.testMode ''
      export IN_DISKO_TEST=1
    ''}
    ${systemToInstall.config.system.build.diskoScript}
  '';

  installer = lib.optionalString cfg.copyNixStore ''
    # populate nix db, so nixos-install doesn't complain
    export NIX_STATE_DIR=${systemToInstall.config.disko.rootMountPoint}/nix/var/nix
    nix-store --load-db < "${closureInfo}/registration"

    # We copy files with cp because `nix copy` seems to have a large memory leak
    mkdir -p ${systemToInstall.config.disko.rootMountPoint}/nix/store
    xargs cp --recursive --target ${systemToInstall.config.disko.rootMountPoint}/nix/store < ${closureInfo}/store-paths

    ${systemToInstall.config.system.build.nixos-install}/bin/nixos-install --root ${systemToInstall.config.disko.rootMountPoint} --system ${systemToInstall.config.system.build.toplevel} --keep-going --no-channel-copy -v --no-root-password --option binary-caches ""
    umount -Rv ${systemToInstall.config.disko.rootMountPoint}
  '';

  QEMU_OPTS = lib.concatStringsSep " " ([
    "-drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
    "-drive if=pflash,format=raw,unit=1,file=efivars.fd"
  ] ++ builtins.map
    (disk:
      "-drive file=${disk.imageName}.${imageFormat},if=virtio,cache=unsafe,werror=report,format=${imageFormat}"
    )
    (lib.attrValues diskoCfg.devices.disk));
in
{
  system.build.diskoImages = vmTools.runInLinuxVM (pkgs.runCommand cfg.name
    {
      buildInputs = dependencies;
      inherit preVM postVM QEMU_OPTS;
      inherit (diskoCfg) memSize;
    }
    (partitioner + installer));

  system.build.diskoImagesScript = diskoLib.writeCheckedBash { inherit checked pkgs; } cfg.name ''
    set -efu
    export PATH=${lib.makeBinPath dependencies}
    showUsage() {
    cat <<\USAGE
    Usage: $script [options]

    Options:
    * --pre-format-files <src> <dst>
      copies the src to the dst on the VM, before disko is run
      This is useful to provide secrets like LUKS keys, or other files you need for formatting
    * --post-format-files <src> <dst>
      copies the src to the dst on the finished image
      These end up in the images later and is useful if you want to add some extra stateful files
      They will have the same permissions but will be owned by root:root
    * --build-memory <amt>
      specify the amount of memory in MiB that gets allocated to the build VM
      This can be useful if you want to build images with a more involed NixOS config
      The default is disko.memSize which defaults to ${builtins.toString options.disko.memSize.default} MiB
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
      origBuilder=${pkgs.writeScript "disko-builder" ''
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
      echo "export origBuilder=$origBuilder" > xchg/saved-env
      ${preVM}
    ''}
    export postVM=${diskoLib.writeCheckedBash { inherit pkgs checked; } "postVM.sh" postVM}

    build_memory=''${build_memory:-${builtins.toString diskoCfg.memSize}}
    QEMU_OPTS=${lib.escapeShellArg QEMU_OPTS}
    QEMU_OPTS+=" -m $build_memory"
    export QEMU_OPTS

    ${pkgs.bash}/bin/sh -e ${vmTools.vmRunCommand vmTools.qemuCommandLinux}
    cd /
  '';
}
