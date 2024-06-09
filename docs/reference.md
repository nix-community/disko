# Reference Manual: disko

## Module Options

We are currently having issues being able to generate proper module option
documentation for our recursive disko types. However you can read the available
options [here](https://github.com/nix-community/disko/tree/master/lib/types).
Combined with the
[examples](https://github.com/nix-community/disko/tree/master/example) this
hopefully gives you an overview.

## Command Line Options

```
Usage: ./disko [options] disk-config.nix
or ./disko [options] --flake github:somebody/somewhere#disk-config

With flakes, disk-config is discovered first under the .diskoConfigurations top level attribute
or else from the disko module of a NixOS configuration of that name under .nixosConfigurations.

Options:

* -m, --mode mode
  set the mode, either format, mount or disko
    format: create partition tables, zpools, lvms, raids and filesystems
    mount: mount the partition at the specified root-mountpoint
    disko: first unmount and destroy all filesystems on the disks we want to format, then run the create and mount mode
* -f, --flake uri
  fetch the disko config relative to this flake's root
* --arg name value
  pass value to nix-build. can be used to set disk-names for example
* --argstr name value
  pass value to nix-build as string
* --root-mountpoint /some/other/mnt
  where to mount the device tree (default: /mnt)
* --dry-run
  just show the path to the script instead of running it
* --no-deps
  avoid adding another dependency closure to an in-memory installer
    requires all necessary dependencies to be available in the environment
* --debug
  run with set -x
```
