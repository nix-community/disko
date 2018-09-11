{ pkgs, ... }:
let
  disko = (builtins.fetchGit {
    url = https://cgit.lassul.us/disko/;
    rev = "88f56a0b644dd7bfa8438409bea5377adef6aef4";
  }) + "/lib";
  cfg = builtins.fromJSON ./tsp-disk.json;
in {
  imports = [
    (disko.config cfg)
  ];
  environment.systemPackages = with pkgs;[
    (pkgs.writeScriptBin "tsp-create" (disko.create cfg))
    (pkgs.writeScriptBin "tsp-mount" (disko.mount cfg))
  ];
}

