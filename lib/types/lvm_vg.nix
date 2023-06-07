{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the volume group";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "lvm_vg" ];
      internal = true;
      description = "Type";
    };
    lvs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = config._module.args.name;
            description = "Name of the logical volume";
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
          content = diskoLib.partitionType { parent = config; };
        };
      }));
      default = { };
      description = "LVS for the volume group";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        diskoLib.deepMergeMap
          (lv:
            lib.optionalAttrs (lv.content != null) (lv.content._meta [ "lvm_vg" config.name ])
          )
          (lib.attrValues config.lvs);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = _:
        let
          sortedLvs = lib.sort (a: _: !lib.hasInfix "100%" a.size) (lib.attrValues config.lvs);
        in
        ''
          readarray -t lvm_devices < <(cat "$disko_devices_dir"/lvm_${config.name})
          vgcreate ${config.name} \
          "''${lvm_devices[@]}"
          ${lib.concatMapStrings (lv: ''
            lvcreate \
              --yes \
              ${if lib.hasInfix "%" lv.size then "-l" else "-L"} ${lv.size} \
              -n ${lv.name} \
              ${lib.optionalString (lv.lvm_type != null) "--type=${lv.lvm_type}"} \
              ${toString lv.extraArgs} \
              ${config.name}
            ${lib.optionalString (lv.content != null) (lv.content._create {dev = "/dev/${config.name}/${lv.name}";})}
          '') sortedLvs}
        '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = _:
        let
          lvMounts = diskoLib.deepMergeMap
            (lv:
              lib.optionalAttrs (lv.content != null) (lv.content._mount { dev = "/dev/${config.name}/${lv.name}"; })
            )
            (lib.attrValues config.lvs);
        in
        {
          dev = ''
            vgchange -a y
            ${lib.concatMapStrings (x: x.dev or "") (lib.attrValues lvMounts)}
          '';
          fs = lvMounts.fs or { };
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        map
          (lv: [
            (lib.optional (lv.content != null) (lv.content._config "/dev/${config.name}/${lv.name}"))
            (lib.optional (lv.lvm_type != null) {
              boot.initrd.kernelModules = [ "dm-${lv.lvm_type}" ];
            })
          ])
          (lib.attrValues config.lvs);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.flatten (map
        (lv:
          lib.optional (lv.content != null) (lv.content._pkgs pkgs)
        )
        (lib.attrValues config.lvs));
      description = "Packages";
    };
  };
}
