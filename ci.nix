let
  pkgs = import <nixpkgs> { };
in
{
  test = pkgs.writeScript "test" ''
    #!/bin/sh
    nix-build "${toString ./tests}";
  '';
}
