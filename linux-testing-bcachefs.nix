# nixpkgs's variant is broken because they have non-applying patches on top of the latest kernel,
# instead of using kernel.

{ lib
, buildLinux
, fetchFromGitHub
, ...
} @ args:
buildLinux (args // {
  # NOTE: bcachefs-tools should be updated simultaneously to preserve compatibility
  version = "6.2.0-2023-03-13";
  modDirVersion = "6.2.0";

  src = fetchFromGitHub {
    owner = "koverstreet";
    repo = "bcachefs";
    rev = "dc2c35d5b4638fc3c569f7630da8782b096fb819";
    sha256 = "sha256-UsSEMeP/itLBzQR/mwt4lAR2rBmqJI9cKjZFI+Lb9cY=";
  };

  kernelPatches = (args.kernelPatches or [ ]) ++ [{
    name = "bcachefs-config";
    patch = null;
    extraConfig = ''
      BCACHEFS_FS m
    '';
  }];
} // (args.argsOverride or { }))
