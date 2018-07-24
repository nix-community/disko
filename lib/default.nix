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

  config.layout = q: x:
    foldl' mergeAttrs {} (mapAttrsToList (name: config-f { device = name; }) x.content);

  config.luks = q: x: {
    boot.initrd.luks.devices.${x.name}.device = q.device;
  } // config-f { device = "/dev/mapper/${x.name}"; } x.content;

  config.lv = q: x:
    config-f { device = "/dev/${q.vgname}/${q.name}"; } x.content;

  config.lvm = q: x:
    foldl' mergeAttrs {} (mapAttrsToList (name: config-f { inherit name; vgname = x.name; }) x.lvs);

  config.partition = q: x:
    config-f { device = q.device + toString q.index; } x.content;

  config.table = q: x:
    foldl' mergeAttrs {} (imap (index: config-f (q // { inherit index; })) x.partitions);


  create-f = q: x: create.${x.type} q x;

  create.filesystem = q: x: ''
    mkfs.${x.format} ${q.device}
  '';

  create.layout = q: x: ''
    ${concatStrings (mapAttrsToList (name: create-f { device = name; }) x.content)}
  '';

  create.luks = q: x: ''
    cryptsetup -q luksFormat ${q.device} ${x.keyfile}
    cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    ${create-f { device = "/dev/mapper/${x.name}"; } x.content}
  '';

  create.lv = q: x: ''
    lvcreate -L ${x.size} -n ${q.name} ${q.vgname}
    ${create-f { device = "/dev/${q.vgname}/${q.name}"; } x.content}
  '';

  create.lvm = q: x: ''
    pvcreate ${q.device}
    vgcreate ${x.name} ${q.device}
    ${concatStrings (mapAttrsToList (name: create-f { inherit name; vgname = x.name; }) x.lvs)}
  '';

  create.partition = q: x: ''
    parted -s ${q.device} mkpart ${x.part-type} ${x.fs-type or ""} ${x.start} ${x.end}
    ${optionalString (x.bootable or false) ''
      parted -s ${q.device} set ${toString q.index} boot on
    ''}
    ${create-f { device = q.device + toString q.index; } x.content}
  '';

  create.table = q: x: ''
    parted -s ${q.device} mklabel ${x.format}
    ${concatStrings (imap (index: create-f (q // { inherit index; })) x.partitions)}
  '';

in
  {
    config = device: config-f { inherit device; };
    create = device: create-f { inherit device; };
  }
