# Running Interactive VMs with disko

disko now exports its own flavor of interactive VMs (similiar to
config.system.build.vm). Simply import the disko module and build the vm runner
with:

```
nix run -L '.#nixosConfigurations.mymachine.config.system.build.vmWithDisko'
```

You can configure the VM using the `virtualisation.vmVariantWithDisko` NixOS
option:

```nix
{
  virtualisation.vmVariantWithDisko = {
    virtualisation.fileSystems."/persist".neededForBoot = true;
    # For running VM on macos: https://www.tweag.io/blog/2023-02-09-nixos-vm-on-macos/
    # virtualisation.host.pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
  };
}
```

extraConfig that is set in disko.tests.extraConfig is also applied to the
interactive VMs. imageSize of the VMs will be determined by the imageSize in the
disk type in your disko config. memorySize is set by disko.memSize
