{
  lib,
  writeShellApplication,
  bash,
  coreutils,
  git,
  nix-fast-build,
}:
writeShellApplication {
  name = "create-release";
  runtimeInputs = [
    bash
    git
    coreutils
    nix-fast-build
  ];
  text = lib.readFile ./create-release.sh;
}
