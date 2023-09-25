# Reference Manual: disko

## Module Options

We are currently having issues being able to generate proper module option
documentation for our recursive disko types. However you can read the available
options [here](https://github.com/nix-community/disko/tree/master/lib/types).
Combined wit the
[examples](https://github.com/nix-community/disko/tree/master/example) this
hopefully gives you an overview.

## # Reference Manual: disko

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

## Generating Disk Images with secrets included

If you have a system config that uses disko then you can run a script that generates a `.raw` VM image.
This image can be used as a VM image, but you can also dd the `.raw` image on to a physical drive and just boot it.
To execute the script replace the `mySystem` part in the snippet below and run it.
```
nix build .#nixosConfigurations.mySystem.config.system.build.diskoImagesScript
```
Now you will have a result file which will output something like this:
```
./result --help
Usage: $script [options]

Options:
* --pre-format-files <src> <dst>
  copies the src to the dst on the VM, before disko is run
  This is useful to provide secrets like LUKS keys, or other files you need for formating
* --post-format-files <src> <dst>
  copies the src to the dst on the finished image
  These end up in the images later and is useful if you want to add some extra stateful files
  They will have the same permissions but will be owned by root:root
* --build-memory
  specify the ammount of memory that gets allocated to the build vm (in mb)
  This can be usefull if you want to build images with a more involed NixOS config
  By default the vm will get 1024M/1GB
* --write-to-disk </dev/disk>
  use an actuall disk instead of writing to a file
  This only works if your conifg has only one disk specified
  There is no check if the specified path is actually a disk so you can also write to another file
```
If you intend to use it with a virtual drive you have to set `disko.devices.disk.<drive>.imageSize = "32G"; #set your own size here` in your disko config.
If you just run the result script it will generate a file per drive specified in `disko.devices.disk.<drive>` called `<dirve>.raw`
There is a small problem with this approach because the `.raw` file will have the size that's specified in `imageSize`+padding.
So with a `imageSize` of `64G` you end up with a `69G` image and if you copy/move that file you end up reading and writing a lot of zeros.
At this point it's probably note worth that there is no auto resizing in disko and it's not planed (but open for contributions).
One way to circumvent that is to use the `--write-to-disk` option and just directly write to a drive,
this only works with one drive but can be useful for simple setups like a laptop configuration.

The way images are generated is basically:
Every file specified in `--pre-format-files` and `--post-format-files` will be copied to a buffer in `/tmp`.
And then copied to the specified locations in the VM before and after the disko partitioning script ran.
After that the NixOS installer will be run which will have access to every file in `--post-format-files` but not `--pre-format-files` because they will already be discarded.
The VM will be shutdown once the installer finishes and then move the `.raw` disk files to the local directory.
