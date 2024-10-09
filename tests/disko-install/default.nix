{ pkgs ? import <nixpkgs> { }, self, diskoVersion }:
let
  disko = pkgs.callPackage ../../package.nix { inherit diskoVersion; };

  dependencies = [
    self.nixosConfigurations.testmachine.pkgs.stdenv.drvPath
    (self.nixosConfigurations.testmachine.pkgs.closureInfo { rootPaths = [ ]; }).drvPath
    self.nixosConfigurations.testmachine.config.system.build.toplevel
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
    def create_test_machine(
        oldmachine=None, **kwargs
    ):  # taken from <nixpkgs/nixos/tests/installer.nix>
        start_command = [
            "${pkgs.qemu_test}/bin/qemu-kvm",
            "-cpu",
            "max",
            "-m",
            "1024",
            "-virtfs",
            "local,path=/nix/store,security_model=none,mount_tag=nix-store",
            "-drive",
            f"file={oldmachine.state_dir}/empty0.qcow2,id=drive1,if=none,index=1,werror=report",
            "-device",
            "virtio-blk-pci,drive=drive1",
        ]
        machine = create_machine(start_command=" ".join(start_command), **kwargs)
        driver.machines.append(machine)
        return machine
    machine.succeed("lsblk >&2")

    print(machine.succeed("tty"))
    machine.succeed("umask 066; echo > /tmp/age.key")
    permission = machine.succeed("stat -c %a /tmp/age.key").strip()
    assert permission == "600", f"expected permission 600 on /tmp/age.key, got {permission}"

    machine.succeed("${disko}/bin/disko-install --disk main /dev/vdb --extra-files /tmp/age.key /var/lib/secrets/age.key --flake ${../..}#testmachine")
    # test idempotency
    machine.succeed("${disko}/bin/disko-install --mode mount --disk main /dev/vdb --flake ${../..}#testmachine")
    machine.shutdown()

    new_machine = create_test_machine(oldmachine=machine, name="after_install")
    new_machine.start()
    name = new_machine.succeed("hostname").strip()
    assert name == "disko-machine", f"expected hostname 'disko-machine', got {name}"
    permission = new_machine.succeed("stat -c %a /var/lib/secrets/age.key").strip()
    assert permission == "600", f"expected permission 600 on /var/lib/secrets/age.key, got {permission}"
  '';
}
