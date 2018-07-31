with import <nixpkgs/lib>;
with builtins;

let {

  body.config = q: x: config.${x.type} q x;
  body.create = q: x: create.${x.type} q x;
  body.mount = q: x: mount.${x.type} q x;


  config.filesystem = q: x: {
    fileSystems.${x.mountpoint} = {
      device = q.device;
      fsType = x.format;
    };
  };

  config.devices = q: x:
    foldl' mergeAttrs {} (mapAttrsToList (name: body.config { device = "/dev/${name}"; }) x.content);

  config.luks = q: x: {
    boot.initrd.luks.devices.${x.name}.device = q.device;
  } // body.config { device = "/dev/mapper/${x.name}"; } x.content;

  config.lv = q: x:
    body.config { device = "/dev/${q.vgname}/${q.name}"; } x.content;

  config.lvm = q: x:
    foldl' mergeAttrs {} (mapAttrsToList (name: body.config { inherit name; vgname = x.name; }) x.lvs);

  config.partition = q: x:
    body.config { device = q.device + toString q.index; } x.content;

  config.table = q: x:
    foldl' mergeAttrs {} (imap (index: body.config (q // { inherit index; })) x.partitions);


  create.filesystem = q: x: ''
    mkfs.${x.format} ${q.device}
  '';

  create.devices = q: x: ''
    ${concatStrings (mapAttrsToList (name: body.create { device = "/dev/${name}"; }) x.content)}
  '';

  create.luks = q: x: ''
    cryptsetup -q luksFormat ${q.device} ${x.keyfile} ${toString (x.extraArgs or [])}
    cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    ${body.create { device = "/dev/mapper/${x.name}"; } x.content}
  '';

  create.lv = q: x: ''
    lvcreate -L ${x.size} -n ${q.name} ${q.vgname}
    ${body.create { device = "/dev/${q.vgname}/${q.name}"; } x.content}
  '';

  create.lvm = q: x: ''
    pvcreate ${q.device}
    vgcreate ${x.name} ${q.device}
    ${concatStrings (mapAttrsToList (name: body.create { inherit name; vgname = x.name; }) x.lvs)}
  '';

  create.partition = q: x: ''
    parted -s ${q.device} mkpart ${x.part-type} ${x.fs-type or ""} ${x.start} ${x.end}
    ${optionalString (x.bootable or false) ''
      parted -s ${q.device} set ${toString q.index} boot on
    ''}
    ${body.create { device = q.device + toString q.index; } x.content}
  '';

  create.table = q: x: ''
    parted -s ${q.device} mklabel ${x.format}
    ${concatStrings (imap (index: body.create (q // { inherit index; })) x.partitions)}
  '';

  mount.filesystem = q: x: {
    fs.${x.mountpoint} = ''
      mkdir -p ${x.mountpoint}
      mount ${q.device} ${x.mountpoint}
    '';
  };

  mount.devices = q: x: let
    z = foldl' recursiveUpdate {} (mapAttrsToList (name: body.mount { device = "/dev/${name}"; }) x.content);
    # attrValues returns values sorted by name.  This is important, because it
    # ensures that "/" is processed before "/foo" etc.
  in ''
    ${concatStringsSep "\n" (attrValues z.luks)}
    ${concatStringsSep "\n" (attrValues z.lvm)}
    ${concatStringsSep "\n" (attrValues z.fs)}
  '';

  mount.luks = q: x: (
    recursiveUpdate
    (body.mount { device = "/dev/mapper/${x.name}"; } x.content)
    {luks.${q.device} = ''
      cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    '';}
  );

  mount.lv = q: x:
    body.mount { device = "/dev/${q.vgname}/${q.name}"; } x.content;

  mount.lvm = q: x: (
    recursiveUpdate
    (foldl' recursiveUpdate {} (mapAttrsToList (name: body.mount { inherit name; vgname = x.name; }) x.lvs))
    {lvm.${q.device} = ''
      vgchange -a y
    '';}
  );

  mount.partition = q: x:
    body.mount { device = q.device + toString q.index; } x.content;

  mount.table = q: x:
    foldl' recursiveUpdate {} (imap (index: body.mount (q // { inherit index; })) x.partitions);

}
