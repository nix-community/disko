{
  # Usage:
  # $ nix flake init --template github:nix-community/disko#hybrid-lvm
  hybrid-lvm = {
    path = ./hybrid-lvm;
    description = "A BIOS/EFI partition template for LVM";
  };
}
