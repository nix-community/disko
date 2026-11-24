# Performing Unattended NixOS Installations

You can use **disko**’s NixOS module in order to perform unattended
installations of NixOS. When performing unattended NixOS installations, you
generally end up having two different NixOS configurations:

1. The deployee configuration. This is the configuration that you are trying to
   install onto a system. You must create this NixOS configuration yourself.

2. The unattended installer configuration. This is the configuration that will
   be used for the installation medium that your will boot into in order to
   start the unattended installation. You can create the unattended installer
   configuration yourself, or you can let **disko**’s NixOS module
   automatically create it for you.

Regardless of which method you choose, unattended installs can be done offline.
The unattended installer should finish successfully regardless of whether or
not the computer that your are installing NixOS on is able to connect to the
Internet.

## Method 1: `nixos-rebuild build-image --image-variant disko-unattended-install-iso`

This first method is designed to make doing unattended installations as easy as
possible. This first method is recommended in most scenarios. In order to
perform an unattended NixOS installation using this method, follow these
instructions:

1. If you have not already, create a deployee configuration. Make sure that the
   deployee configuration imports **disko**’s NixOS module and uses **disko**
   for all of its disks, partitions and filesystems.

    If you aren’t sure how to create such a NixOS configuration, then please
    take some time to use **disko** in order to perform a manual installation
    of NixOS. After you perform a manual installation of NixOS using **disko**,
    you can reuse the NixOS configuration for that installation as the deployee
    configuration for future unattended NixOS installations. For more
    information about how to perform a manual installation of NixOS using
    **disko**, please take a look at [the Quickstart Guide](./quickstart.md).

2. _(Optional)_ In the deployee configuration, customize the value of the
   `image.modules.disko-unattended-install-iso` option. Customizing that option
   will allow you to tweak the unattended installer configuration that will be
   automatically generated for you in a later step. Take a look at [`<disko
   repository>/lib/unattended-install.nix`][unattended-install.nix] for
   documentation about some of the options that you may want to tweak here.

3. Build an unattended install ISO image by doing one of the following:

    - If you did not use flakes when creating your deployee configuration, then
      run this command:

        ```bash
        nixos-rebuild build-image --include nixos-config=<path to deployee configuration.nix> --image-variant disko-unattended-install-iso
        ```

    - If your deployee configuration is available as a flake output, then run
      this command:

        ```bash
        nixos-rebuild build-image --flake <flake URL>#<deployee configuration name> --image-variant disko-unattended-install-iso
        ```

    Once either of those previous commands finishes, there will be a newly
    generate ISO image located inside the `./result/iso` directory.

4. Write the ISO image that’s located in `./result/iso` onto a medium (for
   example: a USB drive). This will turn the medium into an unattended
   installation medium.

    If you aren’t sure how to do this, then please take a look at [the NixOS
    Manual’s “Booting from a USB flash drive”
    section](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb).

5. On the machine that you want to install NixOS on, start booting into the
   unattended installation medium.

6. Once the unattended installation medium starts booting, you will see a menu
   that contains multiple different options. Choose the option that contains
   the text “Disko Unattended NixOS Installer”.

   (That option may not be present in the boot menu if you made certain
   customizations during step 2 of this procedure).

7. Wait for the installation to finish successfully. If the installation
   finishes successfully, then the computer that you are installing NixOS on
   will shut itself down automatically.

   (The computer may not automatically shut down after the installation
   finishes successfully if you made certain customizations during step 2 of
   this procedure).

8. Remove the unattended installation medium from the computer.

9. Turn the computer on. At this point, your new installation of NixOS should
   start booting!

## Method 2: Manually Creating the Unattended Installer Configuration

This second method is designed for advanced users. It’s not as straightforward
as the first method, but it allows for greater customization of the unattended
installation medium (for example, you could create an unattended installation
medium that doesn’t use any ISO 9660 filesystems at all).

The instructions for this method aren’t as specific as the instructions for the
previous method. You’ll need to put in some extra work in order to figure out
exactly how you want to do everything. This method is only recommended for
advanced users.

In order to perform an unattended NixOS installation using this method, follow
these instructions:

1. If you have not already, create a deployee configuration. In your deployee
   configuration, make sure that the `disko.unattendedInstall.enable` option is
   set to `false`.

2. Create an unattended installer configuration. In your unattended installer
   configuration, make sure that the `disko.unattendedInstall.enable` option is
   set to `true`. Also, make sure that you set the
   `disko.unattendedInstall.deployeeConfiguration` option. For more information
   about how to set `disko.unattendedInstall.deployeeConfiguration`, see
   [`<disko repository>/lib/unattended-install.nix`][unattended-install.nix].

3. Somehow, install the unattended installer configuration onto a medium in
   order to turn that medium into an unattended installation medium. You could
   do this using [**disko-install**](./disko-install.md). You could also do
   this by first running `nixos-rebuild build-image` and then writing the
   resulting image to the medium.

4. Boot into the newly created unattended installation medium.

5. Make sure that the `unattendedInstallAtBoot.service` systemd service was
   started during the boot process, or manually start the
   `unattendedInstall.service` systemd service.

[unattended-install.nix]: ../lib/unattended-install.nix
