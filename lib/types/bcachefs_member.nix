# lib/types/bcachefs_member.nix
{ config, options, lib, diskoLib, parent, device, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs_member" ];
      internal = true;
      description = "bcachefs member device type";
    };

    device = lib.mkOption {
      type = lib.types.str;
      description = "Device path";
      default = device;
    };

    pool = lib.mkOption {
      type = lib.types.str;
      description = "Name of the bcachefs pool this device belongs to";
    };

    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };

    label = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Device label";
    };

    discard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable TRIM/discard";
    };

    dataAllowed = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "journal" "btree" "user" ]);
      default = [];
      description = "Allowed data types";
    };

    durability = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Replication factor";
    };


    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo diskoLib.jsonType;
      default = dev: {
        deviceDependencies.bcachefs.${config.pool} = [ dev ];
      };
      description = "Metadata";
    };

    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
        echo BCACHEFS_MEMBER POSITION
        
        echo "${lib.escapeShellArg config.device}" >> "$disko_devices_dir/bcachefs-${config.pool}-members"
    
        # Write all arguments to the file in a single redirection operation
        {
          ${lib.optionalString (config.label != null) ''
            echo "--label=${lib.escapeShellArg config.label}"
          ''}
          ${lib.optionalString config.discard ''
            echo "--discard"
          ''}
          ${lib.optionalString (config.durability != null) ''
            echo "--durability=${toString config.durability}"
          ''}
          ${lib.optionalString (config.dataAllowed != []) ''
            echo "--data=${lib.escapeShellArg (lib.concatStringsSep "," config.dataAllowed)}"
          ''}
          echo "${lib.escapeShellArg config.device}"
        } >> "$disko_devices_dir/bcachefs-${config.pool}-args"
      '';
    };

    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {};
    };

    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default = {};
    };

    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [ ];
      description = "NixOS configuration";
    };

    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.bcachefs-tools ];
      description = "Packages";
    };
  };
}
