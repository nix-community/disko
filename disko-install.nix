{
  stdenvNoCC,
  makeWrapper,
  lib,
  coreutils,
  xcp,
  nixos-install-tools,
}:

stdenvNoCC.mkDerivation {
  name = "disko-install";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin $out/share/disko
    cp -r install-cli.nix $out/share/disko
    sed \
      -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" \
      -e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
      disko-install > $out/bin/disko-install
    chmod 755 $out/bin/disko-install
    wrapProgram $out/bin/disko-install \
      --prefix PATH : "${
        lib.makeBinPath [
          coreutils
          xcp
          nixos-install-tools
        ]
      }"
  '';
  meta = with lib; {
    description = "Disko and nixos-install in one command";
    homepage = "https://github.com/nix-community/disko";
    license = licenses.mit;
    maintainers = with maintainers; [ lassulus ];
    platforms = platforms.linux;
  };
}
