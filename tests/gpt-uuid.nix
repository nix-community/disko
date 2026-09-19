{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  disko = pkgs.callPackage ../. { };
  config = uuid: {
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "gpt";
        partitions.root = {
          size = "100%";
        }
        // pkgs.lib.optionalAttrs (uuid != null) { inherit uuid; };
      };
    };
  };
  generatedUuid = disko._cliFormatNoDeps (config null) pkgs;
  fixedUuid = "809b3a2b-828a-4730-95e1-75b6343e415a";
  configuredUuid = disko._cliFormatNoDeps (config fixedUuid) pkgs;
in
pkgs.runCommand "test-gpt-uuid" { } ''
  if grep -q -- '--partition-guid' ${generatedUuid}/bin/disko-format; then
    echo "sgdisk should generate the UUID when no fixed UUID is configured" >&2
    exit 1
  fi

  grep -q -- '--partition-guid="1:${fixedUuid}"' ${configuredUuid}/bin/disko-format
  touch "$out"
''
