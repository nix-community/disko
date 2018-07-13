# usage: nix-instantiate --eval --json --strict example | jq -r .

with import <nixpkgs/lib>;
with builtins;

let

  f = q: x: fun.${x.type} q x;

  fun.filesystem = q: x: ''
    mkfs.${x.format} ${q.device}
  '';

  fun.luks = q: x: ''
    cryptsetup -q luksFormat ${q.device} ${x.keyfile}
    cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    ${f { device = "/dev/mapper/${x.name}"; } x.content}
  '';

  fun.lv = q: x: ''
    lvcreate -L ${x.size} -n ${q.name} ${q.vgname}
    ${f { device = "/dev/${q.vgname}/${q.name}"; } x.content}
  '';

  fun.lvm = q: x: ''
    pvcreate ${q.device}
    vgcreate ${x.name} ${q.device}
    ${concatStrings (mapAttrsToList (name: f { inherit name; vgname = x.name; }) x.lvs)}
  '';

  fun.partition = q: x: ''
    parted -s ${q.device} mkpart ${x.part-type} ${x.fs-type or ""} ${x.start} ${x.end}
    ${optionalString (x.bootable or false) ''
      parted -s ${q.device} set ${toString q.index} boot on
    ''}
    ${f { device = q.device + toString q.index; } x.content}
  '';

  fun.table = q: x: ''
    parted -s -a optimal ${q.device} mklabel ${x.format}
    ${concatStrings (imap (index: f (q // { inherit index; })) x.partitions)}
  '';

in

  f { device = "/dev/sda"; } (import ./config.nix)
