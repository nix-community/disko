{
  lib,
  config,
  inputs,
  self,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  nixpkgs = inputs.nixpkgs or (throw "No nixpkgs input found");

  flakeOutPaths =
    let
      collector =
        parent:
        map (
          child:
          [ child.outPath ] ++ (if child ? inputs && child.inputs != { } then (collector child) else [ ])
        ) (lib.attrValues parent.inputs);
    in
    lib.unique (lib.flatten (collector self));

  mkInstallClosureModule =
    nixosConfiguration:
    { pkgs, ... }:
    let
      dependencies = [
        nixosConfiguration.config.system.build.toplevel
        nixosConfiguration.config.system.build.diskoScript
        nixosConfiguration.config.system.build.diskoScript.drvPath
        nixosConfiguration.pkgs.stdenv.drvPath

        # https://github.com/NixOS/nixpkgs/blob/f2fd33a198a58c4f3d53213f01432e4d88474956/nixos/modules/system/activation/top-level.nix#L342
        nixosConfiguration.pkgs.perlPackages.ConfigIniFiles
        nixosConfiguration.pkgs.perlPackages.FileSlurp

        (nixosConfiguration.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
      ]
      ++ flakeOutPaths;

      closureInfo = pkgs.closureInfo { rootPaths = dependencies; };
    in
    {
      environment.etc."install-closure".source = "${closureInfo}/store-paths";
    };

  mkInstallScriptModule =
    host:
    { pkgs, ... }:
    let
      diskMapping = lib.concatLists (
        lib.mapAttrsToList (name: path: [
          "--disk"
          name
          path
        ]) host.disks
      );

      args = [
        "--flake"
        "${self}#${host.nixosConfiguration}"
      ]
      ++ diskMapping
      ++ host.script.extraArgs;
    in
    {
      environment.systemPackages = lib.singleton (
        pkgs.writeShellScriptBin host.script.name ''
          set -eux
          exec ${lib.getExe' pkgs.disko "disko-install"} ${lib.escapeShellArgs args}
        ''
      );
    };
in
{
  options = {
    flake.diskoConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = "Instantiated Disko configurations. Used by `disko` and `disko-install`.";
      example = lib.literalExpression ''
        {
          my-pc = {
            disko.devices = {
              disk = {
                my-disk = {
                  device = "/dev/sda";
                  type = "disk";
                  content = {
                    type = "gpt";
                    partitions = {
                      ESP = {
                        type = "EF00";
                        size = "500M";
                        content = {
                          type = "filesystem";
                          format = "vfat";
                          mountpoint = "/boot";
                          mountOptions = [ "umask=0077" ];
                        };
                      };
                      root = {
                        size = "100%";
                        content = {
                          type = "filesystem";
                          format = "ext4";
                          mountpoint = "/";
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        }'';
    };

    disko-install.hosts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              nixosConfiguration = mkOption {
                type = types.str;
                default = name;
                defaultText = lib.literalExpression "<name>";
                description = "Flake attribute for NixOS Configuration to install.";
                example = "my-host";
              };

              disks = mkOption {
                type = types.attrsOf types.path;
                # no default as this should always be set
                description = "Disk names mapped to device paths for disko-install.";
                example = lib.literalExpression "{ vdb = /dev/disk/by-id/some-disk-id; }";
              };

              image = {
                formats = mkOption {
                  type = types.listOf types.str; # TODO stricter typing
                  apply = lib.unique;
                  default = [ "iso-installer" ];
                  description = "Image formats to generate installer images for.";
                  example = "hyperv";
                };

                modules = mkOption {
                  type = types.listOf types.deferredModule;
                  default = [ ];
                  description = "NixOS modules to include in the installer configuration.";
                  example = lib.literalExpression ''
                    { pkgs, ... }:
                    {
                      environment.systemPackages = [ pkgs.git ];
                    }'';
                };
              };

              script = {
                name = mkOption {
                  type = types.str;
                  default = "install-nixos-unattended";
                  description = "Name to use for the unattended installer executable.";
                  example = "my-install-script";
                };

                extraArgs = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "Extra args to pass to disko-install.";
                  example = lib.literalExpression ''[ "--mode" "mount" ]'';
                };
              };
            };
          }
        )
      );
    };
  };

  config.flake.packages = lib.mkMerge (
    lib.concatLists (
      lib.mapAttrsToList (
        name: host:
        let
          nixosConfiguration = self.nixosConfigurations.${host.nixosConfiguration};
          inherit (nixosConfiguration.pkgs.stdenv.hostPlatform) system;

          installerConfiguration = nixpkgs.lib.nixosSystem {
            inherit (nixosConfiguration.pkgs.stdenv.hostPlatform) system;
            modules = [
              (mkInstallClosureModule nixosConfiguration)
              (mkInstallScriptModule host)
            ]
            ++ host.image.modules;
          };
        in
        map (format: {
          ${system}."disko-image-${name}-${format}" =
            installerConfiguration.config.system.build.images.${format};
        }) host.image.formats
      ) config.disko-install.hosts
    )
  );
}
