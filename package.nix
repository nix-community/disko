{
  stdenvNoCC,
  makeWrapper,
  lib,
  path,
  nix,
  coreutils,
  nixos-install-tools,
  binlore,
  diskoVersion,
  stdenv,
}:

let
  self = stdenvNoCC.mkDerivation (finalAttrs: {
    name = "disko";
    src = ./.;
    nativeBuildInputs = [
      makeWrapper
    ];
    installPhase = ''
      mkdir -p $out/bin $out/share/disko
      cp -r install-cli.nix cli.nix default.nix disk-deactivate lib $out/share/disko

      wrapProgram "$out/bin/disko" \
        --set DISKO_VERSION "${diskoVersion}" \
        --prefix NIX_PATH : "nixpkgs=${path}"
        --prefix PATH : ${
          lib.makeBinPath [
            nix
            coreutils
          ]
        }
      ${lib.optionalString (!stdenv.isDarwin) ''
        wrapProgram "$out/bin/disko" \
          --set DISKO_VERSION "${diskoVersion}" \
          --prefix NIX_PATH : "nixpkgs=${path}" \
          --prefix PATH : ${
            lib.makeBinPath [
              nix
              coreutils
              nixos-install-tools
            ]
          } \
      ''}

      for i in $out/bin/; do
        sed -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" "$i" > "$out/bin/$i"
        chmod 755 "$out/bin/$i"
      done
    '';
    # Otherwise resholve thinks that disko and disko-install might be able to execute their arguments
    passthru.binlore.out = binlore.synthesize self ''
      execer cannot bin/.disko-wrapped
      execer cannot bin/.disko-install-wrapped
    '';
    meta = with lib; {
      description = "Format disks with nix-config";
      homepage = "https://github.com/nix-community/disko";
      license = licenses.mit;
      maintainers = with maintainers; [ lassulus ];
      platforms = platforms.unix;
      mainProgram = finalAttrs.name;
    };
  });
in
self
