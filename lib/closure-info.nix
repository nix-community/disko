# This is a modified version of the closure-info derivation from nixpkgs.
# Unlike the original, it does not include hashes in the registration file,
# which might be incorrect if a build is not binary reproducible.

# This derivation builds two files containing information about the
# closure of 'rootPaths': $out/store-paths contains the paths in the
# closure, and $out/registration contains a file suitable for use with
# "nix-store --register-validity".

{ stdenv, coreutils, jq }:

{ rootPaths }:

assert builtins.langVersion >= 5;

stdenv.mkDerivation {
  name = "closure-info";

  __structuredAttrs = true;

  exportReferencesGraph.closure = rootPaths;

  preferLocalBuild = true;

  nativeBuildInputs = [ coreutils jq ];

  empty = rootPaths == [];

  buildCommand =
    ''
      out=''${outputs[out]}

      mkdir $out

      if [[ -n "$empty" ]]; then
        echo 0 > $out/total-nar-size
        touch $out/registration $out/store-paths
      else
        jq -r ".closure | map(.narSize) | add" < "$NIX_ATTRS_JSON_FILE" > $out/total-nar-size
        jq -r '.closure | map([.path, "", (.references | length)] + .references) | add | map("\(.)\n") | add' < "$NIX_ATTRS_JSON_FILE" | head -n -1 > $out/registration
        jq -r '.closure[].path' < "$NIX_ATTRS_JSON_FILE" > $out/store-paths
      fi

    '';
}
