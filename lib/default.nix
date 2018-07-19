with import <nixpkgs/lib>;
with builtins;

let

  config-f = q: x: config.${x.type} q x;

  config.filesystem = q: x: {
    fileSystems.${x.mountpoint} = {
      device = q.device;
      fsType = x.format;
    };
  };

  config.lv = q: x:
    config-f { device = "/dev/${q.vgname}/${q.name}"; } x.content;

  config.luks = q: x: {
    boot.initrd.luks.devices.${x.name}.device = q.device;
  } // config-f { device = "/dev/mapper/${x.name}"; } x.content;

  config.lvm = q: x:
    foldl' mergeAttrs {} (mapAttrsToList (name: config-f { inherit name; vgname = x.name; }) x.lvs);

  config.partition = q: x:
    config-f { device = q.device + toString q.index; } x.content;

  config.table = q: x:
    foldl' mergeAttrs {} (imap (index: config-f (q // { inherit index; })) x.partitions);


  format-f = q: x: format.${x.type} q x;

  format.filesystem = q: x: ''
    mkfs.${x.format} ${q.device}
  '';

  format.lv = q: x: ''
    lvcreate -L ${x.size} -n ${q.name} ${q.vgname}
    ${format-f { device = "/dev/${q.vgname}/${q.name}"; } x.content}
  '';

  format.luks = q: x: ''
    cryptsetup -q luksFormat ${q.device} ${x.keyfile}
    cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    ${format-f { device = "/dev/mapper/${x.name}"; } x.content}
  '';

  format.lvm = q: x: ''
    pvcreate ${q.device}
    vgcreate ${x.name} ${q.device}
    ${concatStrings (mapAttrsToList (name: format-f { inherit name; vgname = x.name; }) x.lvs)}
  '';

  format.partition = q: x: ''
    parted -s ${q.device} mkpart ${x.part-type} ${x.fs-type or ""} ${x.start} ${x.end}
    ${optionalString (x.bootable or false) ''
      parted -s ${q.device} set ${toString q.index} boot on
    ''}
    ${format-f { device = q.device + toString q.index; } x.content}
  '';

  format.table = q: x: ''
    parted -s ${q.device} mklabel ${x.format}
    ${concatStrings (imap (index: format-f (q // { inherit index; })) x.partitions)}
  '';

in
  {
    config = device: config-f { inherit device; };
    format = device: format-f { inherit device; };
  }
