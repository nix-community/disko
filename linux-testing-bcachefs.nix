# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ lib
, buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.2.0-2023-03-22";
  modDirVersion = "6.2.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";

    rev = "169b584fb4c8e51aa36e4b3284f9e2e5ce6f30e4";
    sha256 = "sha256-dHKyh5sI+uZ+lSQQRIuicW9ae6uFaJosLtUbiJuMMrI=";
  };

  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or { }))
