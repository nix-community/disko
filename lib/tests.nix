{
  lib,
  makeTest,
  eval-config,
  qemu-common-lib,
  ...
}:

let
  testLib = {
    # this takes a nixos config and changes the disk devices so we can run them inside the qemu test runner
    # basically changes all the disk.*.devices to something like /dev/vda or /dev/vdb etc.
    #
    # TODO: remove this once the rest of the test machinery moves to per-leaf
    # `disko.devices.disk.<name>.device = lib.mkForce …;` overrides on the
    # existing module-system value. Reassigning the whole `disko.devices`
    # value here is what forces the `_*` stripping below — without that
    # reassignment there'd be no readOnly conflicts to work around.
    prepareDiskoConfig =
      cfg: devices:
      let
        # Strip every `_`-prefixed disko-internal attr (`_config`, `_meta`,
        # `_create`, `_mount`, `_unmount`, `_pkgs`, …) — they're all
        # readOnly+computed and the node eval recomputes them identically.
        # `lib.filterAttrsRecursive` only descends into attrsets, not list
        # elements, so the legacy `partitions = [ … ]` list otherwise keeps
        # its `_config` per entry and collides with filesystem.nix's
        # readOnly default at the node.
        deepStripUnderscore =
          v:
          if lib.isAttrs v then
            lib.mapAttrs (_: deepStripUnderscore) (lib.filterAttrs (n: _: !lib.hasPrefix "_" n) v)
          else if lib.isList v then
            map deepStripUnderscore v
          else
            v;
        cleanedTopLevel = deepStripUnderscore cfg;

        preparedDisks =
          lib.foldlAttrs
            (acc: n: v: {
              devices = lib.tail acc.devices;
              grub-devices =
                acc.grub-devices
                ++ (lib.optional (lib.any (part: (part.type or "") == "EF02") (
                  lib.attrValues (v.content.partitions or { })
                )) (lib.head acc.devices));
              disks = acc.disks // {
                "${n}" = v // {
                  device = lib.head acc.devices;
                  content = v.content // {
                    device = lib.head acc.devices;
                  };
                };
              };
            })
            {
              inherit devices;
              grub-devices = [ ];
              disks = { };
            }
            cleanedTopLevel.disko.devices.disk;
      in
      cleanedTopLevel
      // {
        boot.loader.grub.devices =
          if (preparedDisks.grub-devices != [ ]) then preparedDisks.grub-devices else [ "nodev" ];
        disko.devices = cleanedTopLevel.disko.devices // {
          disk = preparedDisks.disks;
        };
      };

    # list of devices generated inside qemu
    devices = [
      "/dev/vda"
      "/dev/vdb"
      "/dev/vdc"
      "/dev/vdd"
      "/dev/vde"
      "/dev/vdf"
      "/dev/vdg"
      "/dev/vdh"
      "/dev/vdi"
      "/dev/vdj"
      "/dev/vdk"
      "/dev/vdl"
      "/dev/vdm"
      "/dev/vdn"
      "/dev/vdo"
    ];

    makeDiskoTest =
      {
        name,
        disko-config,
        extendModules ? null,
        pkgs ? import <nixpkgs> { },
        extraTestScript ? "",
        bootCommands ? "",
        extraInstallerConfig ? { },
        extraSystemConfig ? { },
        efi ? !pkgs.stdenv.hostPlatform.isRiscV64,
        enableCanokey ? false,
        postDisko ? "",
        testMode ? "module",
        testBoot ? true,
        enableOCR ? false,
      }:
      (import (pkgs.path + "/nixos/lib/eval-config.nix") {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          ../module.nix
          disko-config
          {
            disko.test = {
              inherit
                name
                bootCommands
                efi
                enableOCR
                postDisko
                enableCanokey
                ;
              extraChecks = extraTestScript;
              boot = testBoot;
              mode = testMode;
              nodes.formatter = extraInstallerConfig;
              nodes.machine = extraSystemConfig;
            };
          }
        ];
      }).config.system.build.diskoTest;
  };
in
testLib
