{ stdenvNoCC, makeWrapper, lib, path, nix, coreutils, nixos-install-tools, binlore, diskoVersion }:

let
  shareDir = "share/disko2";
  self = stdenvNoCC.mkDerivation (finalAttrs: {
    name = "disko2";
    src = ./.;
    nativeBuildInputs = [
      makeWrapper
    ];
    installPhase = ''
      mkdir -p $out/bin $out/${shareDir}
      cp -r default.nix disk-deactivate lib $out/${shareDir}
      cp disko2 $out/bin/

      sed -ie "s|libexec_dir = .*|libexec_dir = '$out/${shareDir}'|" $out/${shareDir}/lib/libexec-dir.nu
      sed -ie "s|use lib|use \"$out/${shareDir}/lib\"|" $out/bin/disko2
      chmod 755 "$out/bin/disko2"
      wrapProgram "$out/bin/disko2" \
        --set DISKO_VERSION "${diskoVersion}" \
        --prefix PATH : ${lib.makeBinPath [ nix coreutils nixos-install-tools ]} \
        --prefix NIX_PATH : "nixpkgs=${path}"
    '';
    # Otherwise resholve thinks that disko and disko-install might be able to execute their arguments
    passthru.binlore.out = binlore.synthesize self ''
      execer cannot bin/.disko2-wrapped
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
