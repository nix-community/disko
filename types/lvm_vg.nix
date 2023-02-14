{ config, options, lib, diskoLib, subTypes, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the volume gorup";
    };
    type = lib.mkOption {
      type = lib.types.enum [ "lvm_vg" ];
      internal = true;
      description = "Type";
    };
    lvs = lib.mkOption {
      type = lib.types.attrsOf subTypes.lvm_lv;
      default = { };
      description = "LVS for the volume group";
    };
    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default =
        diskoLib.deepMergeMap (lv: lv._meta [ "lvm_vg" config.name ]) (lib.attrValues config.lvs);
      description = "Metadata";
    };
    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = _: ''
        readarray -t lvm_devices < <(cat "$disko_devices_dir"/lvm_${config.name})
        vgcreate ${config.name} \
        "''${lvm_devices[@]}"
        ${lib.concatMapStrings (lv: lv._create {vg = config.name; }) (lib.attrValues config.lvs)}
      '';
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = _:
        let
          lvMounts = diskoLib.deepMergeMap (lv: lv._mount { vg = config.name; }) (lib.attrValues config.lvs);
        in
        {
          dev = ''
            vgchange -a y
            ${lib.concatMapStrings (x: x.dev or "") (lib.attrValues lvMounts)}
          '';
          fs = lvMounts.fs;
        };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =
        map (lv: lv._config config.name) (lib.attrValues config.lvs);
      description = "NixOS configuration";
    };
    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: lib.flatten (map (lv: lv._pkgs pkgs) (lib.attrValues config.lvs));
      description = "Packages";
    };
  };
}
