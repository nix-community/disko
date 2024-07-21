# Running Interactive VMs with disko

disko now exports it's own flavor of interactive VMs (similiar to config.system.build.vm).
Simply import the disko module and build the vm runner with:
```
nix build -L '.#nixosConfigurations.mymachine.config.system.build.vmWithDisko'
```

afterwards you can run the interactive VM with:

```
result/bin/disko-vm
```

extraConfig that is set in disko.tests.extraConfig is also applied to the interactive VMs.
imageSize of the VMs will be determined by the imageSize in the disk type in your disko config.
memorySize is set by disko.memSize
