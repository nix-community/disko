# Generating Disk Images with Secrets Included using Disko

Using Disko on NixOS allows you to efficiently create `.raw` VM images from a
system configuration. The generated image can be used as a VM or directly
written to a physical drive to create a bootable disk. Follow the steps below to
generate disk images:

## Generating the `.raw` VM Image

1. **Create a NixOS configuration that includes the disko and the disk
   configuration of your choice**

In the this example we create a flake containing a nixos configuration for
`myhost`.

```nix
# save this as flake.nix
{
  description = "A disko images example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, disko, nixpkgs }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # You can get this file from here: https://github.com/nix-community/disko/blob/master/example/simple-efi.nix
        ./simple-efi.nix
        disko.nixosModules.disko
        ({ config, ... }: {
          # shut up state version warning
          system.stateVersion = config.system.nixos.version;
          # Adjust this to your liking.
          # WARNING: if you set a too low value the image might be not big enough to contain the nixos installation
          disko.devices.disk.main.imageSize = "10G";
        })
      ];
    };
  };
}
```

2. **Build the disko image script:** Replace `myhost` in the command below with
   your specific system configuration name:

   ```console
   nix build .#nixosConfigurations.myhost.config.system.build.diskoImagesScript
   ```

3. **Execute the disko image script:** Execute the generated disko image script.
   Running `./result --help` will output the available options:

   ```console
   ./result --help
   Usage: $script [options]

   Options:
   * --pre-format-files <src> <dst>
     copies the src to the dst on the VM, before disko is run
     This is useful to provide secrets like LUKS keys, or other files you need for formatting
   * --post-format-files <src> <dst>
     copies the src to the dst on the finished image
     These end up in the images later and is useful if you want to add some extra stateful files
     They will have the same permissions but will be owned by root:root
   * --build-memory <amt>
     specify the amount of memory in MiB that gets allocated to the build VM
     This can be useful if you want to build images with a more involed NixOS config
     The default is 1024 MiB
   ```

   An example run may look like this:

   ```
   sudo ./result --build-memory 2048
   ```

   The script will generate the actual image outside of the nix store in the
   current working directory. The create image names depend on the names used in
   `disko.devices.disk` attrset in the NixOS configuration. In our code example
   it will produce the following image:

   ```
   $ ls -la main.raw
   .rw-r--r-- root root 10 GB 2 minutes ago main.raw
   ```

## Additional Configuration

- For virtual drive use, define the image size in your Disko configuration:

  ```console
  disko.devices.disk.<drive>.imageSize = "32G"; # Set your preferred size
  ```

- If the `.raw` image size is not optimal, use `--write-to-disk` to write
  directly to a drive. This bypasses the `.raw` file generation, which saves on
  read/write operations and is suitable for single disk setups.

## Understanding the Image Generation Process

1. Files specified in `--pre-format-files` and `--post-format-files` are
   temporarily copied to `/tmp`.
2. Files are then moved to their respective locations in the VM both before and
   after the Disko partitioning script runs.
3. The NixOS installer is executed, having access only to `--post-format-files`.
4. Upon installer completion, the VM is shutdown, and the `.raw` disk files are
   moved to the local directory.

> **Note**: The auto-resizing feature is currently not available in Disko.
> Contributions for this feature are welcomed. Adjust the `imageSize`
> configuration to prevent issues related to file size and padding.

By following these instructions and understanding the process, you can smoothly
generate disk images with Disko for your NixOS system configurations.
