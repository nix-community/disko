{ stdenvNoCC, makeWrapper, lib, path, nix, coreutils, nixos-install-tools, binlore, diskoVersion }:

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

      for i in disko disko-install; do
        sed -e "s|libexec_dir=\".*\"|libexec_dir=\"$out/share/disko\"|" "$i" > "$out/bin/$i"
        chmod 755 "$out/bin/$i"
        wrapProgram "$out/bin/$i" \
          --set DISKO_VERSION "${diskoVersion}" \
          --prefix PATH : ${lib.makeBinPath [ nix coreutils nixos-install-tools ]} \
          --prefix NIX_PATH : "nixpkgs=${path}"
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
      platforms = platforms.linux;
      mainProgram = finalAttrs.name;
    };
  });
in
self
