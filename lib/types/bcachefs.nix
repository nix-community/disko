# lib/types/bcachefs.nix
{ config, options, lib, diskoLib, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the bcachefs pool";
    };

    type = lib.mkOption {
      type = lib.types.enum [ "bcachefs" ];
      default = "bcachefs";
      internal = true;
      description = "Type";
    };

    formatOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional options for bcachefs format";
    };

    mountpoint = lib.mkOption {
      type = lib.types.str;
      description = "Mount point for the bcachefs pool";
    };

    mountOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "defaults" ];
      description = "Options to pass to mount";
      apply = opts: lib.lists.unique (opts ++ [ "nofail" ]);
    };

    uuid = lib.mkOption {
      type = lib.types.strMatching "[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}";
      default = let 
        # Generate a deterministic but random-looking UUID based on the pool name
        # This avoids the need for impure access to nixpkgs at evaluation time
        hash = builtins.hashString "sha256" "${config.name}";
        hexChars = builtins.substring 0 32 hash;
        p1 = builtins.substring 0 8 hexChars;
        p2 = builtins.substring 8 4 hexChars;
        p3 = builtins.substring 12 4 hexChars;
        p4 = builtins.substring 16 4 hexChars;
        p5 = builtins.substring 20 12 hexChars;
      in
        "${p1}-${p2}-${p3}-${p4}-${p5}";
      defaultText = "generated deterministically based on pool name";
      example = "809b3a2b-828a-4730-95e1-75b6343e415a";
      description = ''
        The UUID of the bcachefs filesystem. 
        If not provided, a deterministic UUID will be generated based on the pool name.
      '';
    };

    content = diskoLib.deviceType { parent = config; device = "/dev/bcachefs/${config.name}"; };

    _meta = lib.mkOption {
      internal = true;
      readOnly = true;
      type = diskoLib.jsonType;
      default = lib.optionalAttrs (config.content != null) (config.content._meta ["bcachefs" config.name ]);
      
      description = "Metadata";
    };

    _create = diskoLib.mkCreateOption {
      inherit config options;
      default = ''
          echo BCACHEFS POSITION
          # Read member info from runtime dir - one argument per line
          readarray -t members < <(cat "$disko_devices_dir/bcachefs-${config.name}-members" || true)
          readarray -t member_args < <(cat "$disko_devices_dir/bcachefs-${config.name}-args" || true)
    
          # Format if needed
          if bcachefs show-super "''${members[0]}" >/dev/null 2>&1 && ! (bcachefs show-super "''${members[0]}" 2>&1 | grep -qi "Not a bcachefs superblock"); then
            # Superblock exists and is valid, no reformat needed
            echo "Found existing bcachefs filesystem, skipping format."
          else
            # Need to format - either show-super failed with non-zero exit code
            # or it returned "Not a bcachefs superblock" message
            echo "No valid bcachefs filesystem found, formatting..."
            # bcachefs format --force "''${member_args[@]}" ${toString config.formatOptions}
              # Add some sleep and sync to ensure all previous operations are complete

            sync
            sleep 1
  
            # Try formatting with additional error handling
            format_attempts=0
            max_attempts=3
            format_success=false
  
            while [ $format_attempts -lt $max_attempts ] && [ "$format_success" = "false" ]; do
              format_attempts=$((format_attempts + 1))
              echo "Format attempt $format_attempts of $max_attempts..."
    
              if bcachefs format --force --uuid=${config.uuid} "''${member_args[@]}" ${toString config.formatOptions}; then
                format_success=true
                echo "Format successful"
              else
                format_exit=$?
                echo "Format failed with exit code $format_exit, waiting before retry..."
                sync
                sleep 2
              fi
            done
  
            if [ "$format_success" = "false" ]; then
              echo "Failed to format bcachefs filesystem after $max_attempts attempts"
              exit 1
            fi

            udevadm trigger --subsystem-match=block
            udevadm settle
          fi

          ${lib.optionalString (config.content != null) config.content._create}
      '';
    };

    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {
        fs.${config.mountpoint} = ''
          if ! findmnt "${config.mountpoint}" > /dev/null 2>&1; then
            ### Hacky work around since bcachefs is broken on earlier kernels
            mkdir -p "${config.mountpoint}"
    
            # Capture both the exit code and output of the mount command
            output=$(bcachefs mount ${lib.optionalString (config.mountOptions != []) "-o ${lib.concatStringsSep "," config.mountOptions}"} UUID="${config.uuid}" "${config.mountpoint}" 2>&1)
            exit_code=$?
    
            # Check if the error contains "No such device"
            if echo "$output" | grep -q "No such device"; then
                echo "Notice: bcachefs mount failed with 'No such device'. This is expected on kernels < 6.13."
                echo "Current kernel version: $(uname -r)"
                echo "The mount will succeed when you boot into your final system with a newer kernel."
            else
                # Propagate the output and exit code if it's not the expected error
                echo "$output"
                exit $exit_code
            fi
        fi
        '';
      };
    };

    _unmount = diskoLib.mkUnmountOption {
      inherit config options;
      default = {
        fs.${config.mountpoint} = ''
          if findmnt "${config.mountpoint}" > /dev/null 2>&1; then
            umount "${config.mountpoint}"
          fi
        '';
      };
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default =[
        {
          # Basic bcachefs support
          boot.supportedFilesystems = [ "bcachefs" ];
          boot.kernelModules = [ "bcachefs" ];
          # use latest kernel
          # boot.kernelPackages = config._pkgs.linuxPackages_latest;

          # environment.systemPackages = with lib.pkgs; [
          #   bcachefs-tools
          #   util-linux
          # ];

        }
        {
          fileSystems.${config.mountpoint} = {
            device = "UUID=${config.uuid}";
            fsType = "bcachefs";
            options = config.mountOptions;
          };
          # Add systemd environment variable for the mount unit
          systemd.services."mount-${lib.escapeSystemdPath config.mountpoint}".serviceConfig.Environment = "BCACHEFS_BLOCK_SCAN=1";
          systemd.services."unlock-bcachefs-${lib.escapeSystemdPath config.mountpoint}".serviceConfig.Environment = "BCACHEFS_BLOCK_SCAN=1";
    
##############################################################################
# WORKAROUND: Until the following can be addressed. This means using
# multi-disk bcachefs as a boot/root partition is not possible in its current
# form with disko
# https://github.com/koverstreet/bcachefs-tools/issues/308
# https://github.com/systemd/systemd/issues/8234#issuecomment-1868238750
##############################################################################
          systemd.services."mount-${lib.replaceStrings ["/"] ["-"] config.mountpoint}" = {
            description = "Mount bcachefs filesystem at ${config.mountpoint}";
            before = [ "local-fs.target" ];
            requires = [ "local-fs-pre.target" ];
            after = [ "local-fs-pre.target" ];
            environment = {
              BCACHEFS_BLOCK_SCAN = "1";
            };
            script = ''
              mkdir -p ${config.mountpoint}
              mount -t bcachefs UUID=${config.uuid} ${config.mountpoint} -o ${lib.concatStringsSep "," config.mountOptions} -o X-mount.mkdir
            '';
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
          };
##############################################################################
        }
      ];
    };

    _pkgs = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = pkgs: [ pkgs.bcachefs-tools ];
    };
  };
}
