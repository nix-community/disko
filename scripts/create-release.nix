{
  lib,
  writeShellApplication,
  bash,
  git,
  coreutils,
}:
writeShellApplication {
  name = "create-release";
  runtimeInputs = [
    bash
    git
    coreutils
  ];
  text = lib.readFile ./create-release.sh;
}
