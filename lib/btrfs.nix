{ config, options, diskoLib, lib, rootMountPoint, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "btrfs" ];
      internal = true;
      description = "Type";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "A list of options to pass to mount.";
    };
    subvolumes = lib.mkOption {
      type = lib.types.attrsOf diskoLib.types.btrfs_subvol;
      default = { };
      description = "Subvolumes to define for BTRFS.";
    };
    mountpoint = lib.mkOption {
      type = lib.types.nullOr diskoLib.optionTypes.absolute-pathname;
      default = null;
      description = "A path to mount the BTRFS filesystem to.";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        diskoLib.deepMergeMap (subvol: subvol._meta dev) (lib.attrValues config.subvolumes);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { dev }: ''
        mkfs.btrfs ${dev} ${toString config.extraArgs}
        ${lib.concatMapStrings (subvol: subvol._create { inherit dev; }) (lib.attrValues config.subvolumes)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { dev }:
        let
          subvolMounts = diskoLib.deepMergeMap (subvol: subvol._mount { inherit dev; parent = config.mountpoint; }) (lib.attrValues config.subvolumes);
        in
        {
          fs = subvolMounts.fs // lib.optionalAttrs (config.mountpoint != null) {
            ${config.mountpoint} = ''
              if ! findmnt ${dev} "${rootMountPoint}${config.mountpoint}" > /dev/null 2>&1; then
                mount ${dev} "${rootMountPoint}${config.mountpoint}" \
                ${lib.concatMapStringsSep " " (opt: "-o ${opt}") config.mountOptions} \
                -o X-mount.mkdir
              fi
            '';
          };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = dev: [
        (map (subvol: subvol._config dev config.mountpoint) (lib.attrValues config.subvolumes))
        (lib.optional (config.mountpoint != null) {
          fileSystems.${config.mountpoint} = {
            device = dev;
            fsType = "btrfs";
            options = config.mountOptions;
          };
        })
      ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs:
        [ pkgs.btrfs-progs ] ++ lib.flatten (map (subvolume: subvolume._pkgs pkgs) (lib.attrValues config.subvolumes));
      description = "Packages";
    };
  };
}
