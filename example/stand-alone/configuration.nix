{ pkgs, lib, ... }:
let
  disko = import (builtins.fetchGit {
    url = "https://github.com/nix-community/disko";
    ref = "master";
  }) {
    inherit lib;
  };
  cfg = {
    type = "devices";
    content = {
      sda = {
        type = "table";
        format = "msdos";
        partitions = [{
          type = "partition";
          part-type = "primary";
          start = "1M";
          end = "100%";
          bootable = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }];
      };
    };
  };
in {
  imports = [
    (disko.config cfg)
  ];
  environment.systemPackages = with pkgs;[
    (pkgs.writeScriptBin "tsp-create" (disko.create cfg))
    (pkgs.writeScriptBin "tsp-mount" (disko.mount cfg))
  ];
}

