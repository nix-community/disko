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
      type = lib.types.str;
      default = "";
      description = "Extra arguments";
    };
    content = diskoLib.partitionType;
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev:
        lib.optionalAttrs (!isNull config.content) (config.content._meta dev);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = { vg }: ''
        lvcreate \
          --yes \
          ${if lib.hasInfix "%" config.size then "-l" else "-L"} ${config.size} \
          -n ${config.name} \
          ${lib.optionalString (!isNull config.lvm_type) "--type=${config.lvm_type}"} \
          ${config.extraArgs} \
          ${vg}
        ${lib.optionalString (!isNull config.content) (config.content._create {dev = "/dev/${vg}/${config.name}";})}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = { vg }:
        lib.optionalAttrs (!isNull config.content) (config.content._mount { dev = "/dev/${vg}/${config.name}"; });
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = vg:
        [
          (lib.optional (!isNull config.content) (config.content._config "/dev/${vg}/${config.name}"))
          (lib.optional (!isNull config.lvm_type) {
            boot.initrd.kernelModules = [ "dm-${config.lvm_type}" ];
          })
        ];
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.optionals (!isNull config.content) (config.content._pkgs pkgs);
      description = "Packages";
    };
  };
}
