# Regression test for https://github.com/nix-community/disko/issues/1310
# enrollFido2 must preserve crypttabExtraOpts from settings rather than having
# them overwrite "fido2-device=auto".
{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  evalLuks =
    luksAttrs:
    (pkgs.nixos [
      ../module.nix
      {
        documentation.enable = false;
        system.stateVersion = "26.11";
        disko.devices.disk.main = {
          type = "disk";
          device = "/dev/vdb";
          content = {
            type = "gpt";
            partitions.luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                enrollRecovery = false;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              }
              // luksAttrs;
            };
          };
        };
      }
    ]).config.boot.initrd.luks.devices.crypted;

  withExtraOpts = evalLuks {
    enrollFido2 = true;
    settings = {
      allowDiscards = true;
      crypttabExtraOpts = [ "tpm2-device=auto" ];
    };
  };

  withoutExtraOpts = evalLuks {
    enrollFido2 = true;
    settings.allowDiscards = true;
  };

  withoutFido2 = evalLuks {
    enrollFido2 = false;
    settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  withCustomDevice = evalLuks {
    enrollFido2 = true;
    settings = {
      device = "/dev/disk/by-id/custom";
      crypttabExtraOpts = [ "tpm2-device=auto" ];
    };
  };
in
assert
  builtins.sort builtins.lessThan withExtraOpts.crypttabExtraOpts == [
    "fido2-device=auto"
    "tpm2-device=auto"
  ];
assert withExtraOpts.allowDiscards;
assert withoutExtraOpts.crypttabExtraOpts == [ "fido2-device=auto" ];
assert withoutFido2.crypttabExtraOpts == [ "tpm2-device=auto" ];
assert withCustomDevice.device == "/dev/disk/by-id/custom";
assert
  builtins.sort builtins.lessThan withCustomDevice.crypttabExtraOpts == [
    "fido2-device=auto"
    "tpm2-device=auto"
  ];
pkgs.runCommand "test-luks-fido2-crypttab-opts" { } "touch $out"
