# usage: nix-instantiate --eval --json --strict example | jq -r .

with import <nixpkgs/lib>;
with builtins;

let

  fun.filesystem = q: x: ''
    mkfs.${x.format} ${q.device}
  '';

  fun.lvm = q: x: ''
    pvcreate ${q.device}
    vgcreate ${x.name} ${q.device}
    ${concatStringsSep "\n" (mapAttrsToList (name: f (q // { inherit name; vgname = x.name; device = null; /* ??? */ })) x.lvs)}
  '';

  fun.luks = q: x: ''
    cryptsetup -q luksFormat ${q.device} ${x.keyfile}
    cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}

    ${f (q // { device = "/dev/mapper/${x.name}"; }) x.content}
  '';

  fun.partition = q: x:
    "(part ${toString (map (f q) (children x))})";

  fun.table = q: x: ''
    parted -s -a optimal ${q.device} mklabel ${x.format}
    ${concatStrings (imap (i: part: " \nparted -s -a optimal ${q.device} mkpart ${part.part-type} ${part.fs-type or ""} ${part.start} ${part.end} ${optionalString (part.bootable or false) "\nparted -s -a optimal ${q.device} set ${toString i} boot on "}") x.partitions)}

    ${concatStrings (imap (i: x: f (q // { device = q.device + toString i; }) x.content) x.partitions)}
  '';

  fun.lv = q: x: ''
    lvcreate -L ${x.size} -n ${q.name} ${q.vgname}

    ${f (q // { device = "/dev/${q.vgname}/${q.name}"; }) x.content}
  '';

  children = x: {
    lvm = attrValues x.lvs;
    luks = [x.content];
    partition = [x.content];
    table = x.partitions;
    lv = [x.content];
  }.${x.type};

  f = q: x: fun.${x.type} q x;

  q0.device = "/dev/sda";
  x0 = import ./config.nix;
in
  f q0 x0
