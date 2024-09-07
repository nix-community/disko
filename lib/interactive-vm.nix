# We need to specify extendModules here to ensure that it is available
# in args for makeDiskImages
{ diskoLib, modulesPath, config, pkgs, lib, extendModules, ... }@args:

let
  vm_disko = (diskoLib.testLib.prepareDiskoConfig config diskoLib.testLib.devices).disko;
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
    nixosConfig = args;
    copyNixStore = false;
    extraConfig = {
      disko.devices = cfg_.disko.devices;
    };
    testMode = true;
    imageFormat = "qcow2";
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

  diskoBasedConfiguration = {
    # generated from disko config
    virtualisation.fileSystems = cfg_.disko.devices._config.fileSystems;
    boot = cfg_.disko.devices._config.boot or { };
    swapDevices = cfg_.disko.devices._config.swapDevices or [ ];
  };
in
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    diskoBasedConfiguration
  ];

  virtualisation.useEFIBoot = config.disko.tests.efi;
  virtualisation.memorySize = config.disko.memSize;
  virtualisation.useDefaultFilesystems = false;
  virtualisation.diskImage = null;
  virtualisation.qemu.drives = [ rootDisk ] ++ otherDisks;
  boot.zfs.devNodes = "/dev/disk/by-uuid"; # needed because /dev/disk/by-id is empty in qemu-vms
  boot.zfs.forceImportAll = true;

  system.build.vmWithDisko = pkgs.writers.writeDashBin "disko-vm" ''
    set -efux
    export tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    ${lib.concatMapStringsSep "\n" (disk: ''
      ${pkgs.qemu}/bin/qemu-img create -f qcow2 \
      -b ${diskoImages}/${disk.name}.qcow2 \
      -F qcow2 "$tmp"/${disk.name}.qcow2
    '') disks}
    set +f
    ${config.system.build.vm}/bin/run-*-vm
  '';
}
