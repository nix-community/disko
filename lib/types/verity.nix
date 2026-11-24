{ config, options, lib, diskoLib, parent, ... }:
# EXPERIMENTAL: This module provides verification of install images through dm-verity
# We do not provide updating nixos configuration through nixos-rebuild switch, when using this.
# This is mainly useful in the context of generated images, that are booted with secure boot.
let
  diskoConfig = config;
in
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [ "verity" ];
      internal = true;
      description = "Type";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = config._module.args.name;
      description = "Name of the veritysetup device";
    };
    # can we get those from device directly?
    dataDevice = lib.mkOption {
      type = lib.types.str;
      description = "Device to store the data";
    };
    hashDevice = lib.mkOption {
      type = lib.types.str;
      description = "Device to store the merkle tree";
    };
    extraFormatArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `veritysetup format`";
      example = [ "--debug" ];
    };
    extraOpenArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments to pass to `cryptsetup luksOpen` when opening";
      example = [ "--timeout 10" ];
    };
    content = diskoLib.deviceType { parent = config; device = "/dev/mapper/${config.name}"; };
    _parent = lib.mkOption {
      internal = true;
      default = parent;
    };
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
      default = {};
    };
    _mount = diskoLib.mkMountOption {
      inherit config options;
      default = {};
    };
    _unmount = diskoLib.mkMountOption {
      inherit config options;
      default = {};
    };
    _config = lib.mkOption {
      internal = true;
      readOnly = true;
      default = [
        ({config, pkgs, ...}: {
          # Maybe secureboot should be left to the user?
          boot.uki.settings = {
            # TODO
            # SecureBootPrivateKey = "./out";
          };
          # TODO: upstream this.
          assertions = [
            {
              assertion = config.boot.inird.systemd.enable;
              message = ''
                veritysetup with disko requires systemd in the initrd to be enabled.
              '';
            }
          ];
          # TODO: we want actually
          boot.kernelParams = [
            "systemd.verity_root_data=${diskoConfig.dataDevice}"
            "systemd.verity_root_hash=${diskoConfig.hashDevice}"
          ];
          boot.initrd = {
            availableKernelModules = [ "dm_mod" "dm_verity" ];
            # We need LVM for dm-verity to work.
            services.lvm.enable = true;

            systemd = {
              additionalUpstreamUnits = [ "veritysetup-pre.target" "veritysetup.target" "remote-veritysetup.target" ];
              storePaths = [
                "${config.boot.initrd.systemd.package}/lib/systemd/systemd-veritysetup"
                "${config.boot.initrd.systemd.package}/lib/systemd/system-generators/systemd-veritysetup-generator"
              ];
            };
          };

          boot.bootspec.enable = true;
          boot.loader.external = {
            enable = true;
            installHook =
              let
                bootspecNamespace = ''"org.nixos.bootspec.v1"'';
                installer = pkgs.writeShellApplication {
                  name = "install-uki";
                  runtimeInputs = with pkgs; [ jq systemd binutils ];
                  text = ''
                    boot_json=/nix/var/nix/profiles/system-1-link/boot.json
                    tempdir=$(mktemp -d)
                    trap 'rm -rf "$tempdir"' EXIT
                    kernel=$(jq -r '.${bootspecNamespace}.kernel' "$boot_json")
                    initrd=$(jq -r '.${bootspecNamespace}.initrd' "$boot_json")
                    init=$(jq -r '.${bootspecNamespace}.init' "$boot_json")

                    # TODO: get access to the unmount script for config.dataDevice by injecting toplevel-config into disko
                    veritysetup format ${config.dataDevice} ${config.hashDevice} \
                      --root-hash-file "$tempdir/verity_roothash_${config.name}"

                    ${pkgs.systemdUkify}/lib/systemd/ukify \
                      "$kernel" \
                      "$initrd" \
                      --stub="${pkgs.systemd}/lib/systemd/boot/efi/linux${pkgs.hostPlatform.efiArch}.efi.stub" \
                      --cmdline="init=$init ${builtins.toString config.boot.kernelParams} roothash=$(<$tempdir/verity_roothash_${config.name})" \
                      --os-release="@${config.system.build.etc}/etc/os-release" \
                      --output=uki.efi

                    esp=${config.boot.loader.efi.efiSysMountPoint}

                    bootctl install --esp-path="$esp"
                    install uki.efi "$esp"/EFI/Linux/
                  '';
                };
              in
              "${lib.getExe installer}";
          };

        })
      ] ++ (lib.optional (config.content != null) config.content._config);
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
