{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the logical volume";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "lvm_lv" ];
      default = "lvm_lv";
      internal = true;
      description = "Type";
    };
    size = lib.mkOption {
      type = lib.types.str; # TODO lvm size type
      description = "Size of the logical volume";
    };
    lvm_type = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "mirror" "raid0" "raid1" ]); # TODO add all lib.types
      default = null; # maybe there is always a default type?
      description = "LVM type";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments";
    };
    content = diskoLib.partitionType;
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.optionalAttrs (config.content != null) (config.content._meta dev);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { vg }: ''
        lvcreate \
          --yes \
          ${if lib.hasInfix "%" config.size then "-l" else "-L"} ${config.size} \
          -n ${config.name} \
          ${lib.optionalString (config.lvm_type != null) "--type=${config.lvm_type}"} \
          ${toString config.extraArgs} \
          ${vg}
        ${lib.optionalString (config.content != null) (config.content._create {dev = "/dev/${vg}/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { vg }:
        lib.optionalAttrs (config.content != null) (config.content._mount { dev = "/dev/${vg}/${config.name}"; });
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = vg:
        [
          (lib.optional (config.content != null) (config.content._config "/dev/${vg}/${config.name}"))
          (lib.optional (config.lvm_type != null) {
            boot.initrd.kernelModules = [ "dm-${config.lvm_type}" ];
          })
        ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.optionals (config.content != null) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
