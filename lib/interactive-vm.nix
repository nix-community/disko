{ nixosConfig
, diskoLib
, pkgs ? nixosConfig.pkgs
, name ? "${nixosConfig.config.networking.hostName}-disko-images"
, extraConfig ? { }
}:
let
  lib = pkgs.lib;
  vm_disko = (diskoLib.testLib.prepareDiskoConfig nixosConfig.config diskoLib.testLib.devices).disko;
  cfg_ = (lib.evalModules {
    modules = lib.singleton {
      # _file = toString input;
      imports = lib.singleton { disko.devices = vm_disko.devices; };
      options = {
        disko.devices = lib.mkOption {
          type = diskoLib.toplevel;
        };
        disko.testMode = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
    };
  }).config;
  disks = lib.attrValues cfg_.disko.devices.disk;
  diskoImages = diskoLib.makeDiskImages {
    nixosConfig = nixosConfig;
    copyNixStore = false;
    extraConfig = {
      disko.devices = cfg_.disko.devices;
    };
    testMode = true;
  };
  rootDisk = {
    name = "root";
    file = ''"$tmp"/${(builtins.head disks).name}.qcow2'';
    driveExtraOpts.cache = "writeback";
    driveExtraOpts.werror = "report";
    deviceExtraOpts.bootindex = "1";
    deviceExtraOpts.serial = "root";
  };
  otherDisks = map
    (disk: {
      name = disk.name;
      file = ''"$tmp"/${disk.name}.qcow2'';
      driveExtraOpts.werror = "report";
    })
    (builtins.tail disks);
  vm = (nixosConfig.extendModules {
    modules = [
      ({ modulesPath, ... }: {
        imports = [
          (modulesPath + "/virtualisation/qemu-vm.nix")
        ];
      })
      {
        virtualisation.useEFIBoot = nixosConfig.config.disko.tests.efi;
        virtualisation.memorySize = nixosConfig.config.disko.memSize;
        virtualisation.useDefaultFilesystems = false;
        virtualisation.diskImage = null;
        virtualisation.qemu.drives = [ rootDisk ] ++ otherDisks;
        boot.zfs.devNodes = "/dev/disk/by-uuid"; # needed because /dev/disk/by-id is empty in qemu-vms
        boot.zfs.forceImportAll = true;
      }
      {
        # generated from disko config
        virtualisation.fileSystems = cfg_.disko.devices._config.fileSystems;
        boot = cfg_.disko.devices._config.boot or { };
        swapDevices = cfg_.disko.devices._config.swapDevices or [ ];
      }
      nixosConfig.config.disko.tests.extraConfig
    ];
  }).config.system.build.vm;
in
{
  pure = pkgs.writeDashBin "disko-vm" ''
    set -efux
    export tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    ${lib.concatMapStringsSep "\n" (disk: ''
      ${pkgs.qemu}/bin/qemu-img create -f qcow2 \
      -b ${diskoImages}/${disk.name}.raw \
      -F raw "$tmp"/${disk.name}.qcow2
    '') disks}
    set +f
    ${vm}/bin/run-*-vm
  '';
}
