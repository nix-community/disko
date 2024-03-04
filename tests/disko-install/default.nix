{ pkgs ? import <nixpkgs> { }, self }:
let
  disko-install = pkgs.callPackage ../../disko-install.nix { };
  toplevel = self.nixosConfigurations.testmachine.config.system.build.toplevel;

  dependencies = [
    pkgs.stdenv.drvPath
    toplevel
    self.nixosConfigurations.testmachine.config.system.build.diskoScript
  ] ++ builtins.map (i: i.outPath) (builtins.attrValues self.inputs);

  closureInfo = pkgs.closureInfo { rootPaths = dependencies; };
in
pkgs.nixosTest {
  name = "disko-test";
  nodes.machine = {
    virtualisation.emptyDiskImages = [ 4096 ];
    virtualisation.memorySize = 3000;
    environment.etc."install-closure".source = "${closureInfo}/store-paths";
  };

  testScript = ''
    def create_test_machine(oldmachine, args={}): # taken from <nixpkgs/nixos/tests/installer.nix>
        startCommand = "${pkgs.qemu_test}/bin/qemu-kvm"
        startCommand += " -cpu max -m 1024 -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store"
        startCommand += f' -drive file={oldmachine.state_dir}/empty0.qcow2,id=drive1,if=none,index=1,werror=report'
        startCommand += ' -device virtio-blk-pci,drive=drive1'
        machine = create_machine({
          "startCommand": startCommand,
        } | args)
        driver.machines.append(machine)
        return machine
    machine.succeed("lsblk >&2")

    print(machine.succeed("tty"))
    machine.succeed("${disko-install}/bin/disko-install --disk main /dev/vdb --flake ${../..}#testmachine")
    # test idempotency
    machine.succeed("${disko-install}/bin/disko-install --mode mount --disk main /dev/vdb --flake ${../..}#testmachine")
    machine.shutdown()

    new_machine = create_test_machine(oldmachine=machine, args={ "name": "after_install" })
    new_machine.start()
    name = new_machine.succeed("hostname").strip()
    assert name == "disko-machine", f"expected hostname 'disko-machine', got {name}"
  '';
}
