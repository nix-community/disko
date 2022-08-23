{ lib }:
with lib;
with builtins;

let {

  body.config = config-f {};
  body.create = create-f {};
  body.mount = mount-f {};


  helper.find-device = device: let
    environment = helper.device-id device;
  in
    # DEVICE points already to /dev/disk, so we don't handle it via /dev/disk/by-path
    if hasPrefix "/dev/disk" device then
       "${environment}='${device}'"
    else ''
      ${environment}=$(for x in /dev/disk/by-path/*; do
        dev=$x
        if [ "$(readlink -f $x)" = '${device}' ]; then
          target=$dev
          break
        fi
      done
      if test -z $target; then
        echo 'unable to find path of disk: ${device}, bailing out' >&2
        exit 1
      else
        echo $target
      fi)
    '';

  helper.device-id = device: "DEVICE${builtins.substring 0 5 (builtins.hashString "sha1" device)}";

  config-f = q: x: config.${x.type} q x;

  config.filesystem = q: x: {
    fileSystems.${x.mountpoint} = {
      device = q.device;
      fsType = x.format;
      ${if x ? options then "options" else null} = x.options;
    };
  };

  config.devices = q: x:
    foldl' recursiveUpdate {} (mapAttrsToList (name: config-f { device = "/dev/${name}"; }) x.content);

  config.luks = q: x: {
    boot.initrd.luks.devices.${x.name}.device = q.device;
  } // config-f { device = "/dev/mapper/${x.name}"; } x.content;

  config.lv = q: x:
    config-f { device = "/dev/mapper/${q.vgname}-${q.name}"; } x.content;

  config.lvm = q: x:
    foldl' recursiveUpdate {} (mapAttrsToList (name: config-f { inherit name; vgname = x.name; }) x.lvs);

  config.noop = q: x: {};
  # FIXME: what do we need here?
  config.mdraid = q: x: {};

  config.partition = q: x:
    config-f { device = q.device + toString q.index; } x.content;

  config.table = q: x:
    foldl' recursiveUpdate {} (imap (index: config-f (q // { inherit index; })) x.partitions);


  create-f = q: x: create.${x.type} q x;

  create.filesystem = q: x: optionalString (q.stage == 1) ''
    mkfs.${x.format} ${q.device}
  '';

  create.devices = q: x: ''
    declare -A MDRAIDS MDRAID_LEVELS
    ${concatStrings (mapAttrsToList (name: create-f { device = "/dev/${name}"; stage = 1; }) x.content)}
    for raid in "''${!MDRAIDS[@]}"; do
      level="''${MDRAID_LEVELS[$raid]:-1}"
      devices="MDRAID_$raid[@]"
      devices_num="MDRAID_''${raid}_num"
      echo "y" | mdadm --create /dev/md/$raid --level=$level --raid-devices="''${!devices_num}" "''${!devices}"
    done
    ${concatStrings (mapAttrsToList (name: create-f { device = "/dev/${name}"; stage = 2; }) x.content)}
  '';

  create.luks = q: x: ''
    ${optionalString (q.stage == 1) ''
      cryptsetup -q luksFormat ${q.device} ${x.keyfile} ${toString (x.extraArgs or [])}
      cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    ''}
    ${create-f { device = "/dev/mapper/${x.name}"; inherit (q) stage; } x.content}
  '';

  create.lv = q: x: ''
    ${optionalString (q.stage == 1) "lvcreate -L ${x.size} -n ${q.name} ${q.vgname}"}
    ${create-f { device = "/dev/mapper/${q.vgname}-${q.name}"; inherit (q) stage; } x.content}
  '';

  create.lvm = q: x: ''
    ${optionalString (q.stage == 1) ''
      pvcreate ${q.device}
      vgcreate ${x.name} ${q.device}
    ''}
    ${concatStrings (mapAttrsToList (name: create-f { inherit name; vgname = x.name; inherit (q) stage; }) x.lvs)}
  '';

  create.noop = q: x: "";

  # TODO metadata version?
  create.mdraid = q: x: if q.stage == 1 then ''
    MDRAIDS[${x.name}]=1
    ${optionalString ((q.level or null) != null) ''
      if [[ "''${MDRAID_LEVELS[${x.name}+abc]}" && "''${MDRAID_LEVELS[${x.name}]}" != ${q.level} ]]; then
        echo "Raid level of mdraid ${x.name} was redefined with a different raid level ${q.level} != ''${MDRAID_LEVELS[${x.name}]}" >&2
        exit 1
      fi
      MDRAID_LEVELS[${x.name}]=${q.level}
    ''}
    if [[ ! -v MDRAID_${x.name}[@] ]]; then
      MDRAID_${x.name}=()
      MDRAID_${x.name}_num=0
    fi
    MDRAID_${x.name}+=("${q.device}")
    ((MDRAID_${x.name}_num=MDRAID_${x.name}_num+1))
  '' else
    create-f { device = "/dev/md/${x.name}"; stage = 1; } x.content;

  create.partition = q: x: let
    env = helper.device-id q.device;
  in  ''${optionalString (q.stage == 1) ''
      parted --align ${x.align or "optimal"} -s "''${${env}}" mkpart ${x.part-type} ${x.fs-type or ""} ${x.start} ${x.end}
      # ensure /dev/disk/by-path/..-partN exists before continuing
      udevadm trigger --subsystem-match=block; udevadm settle
      ${optionalString (x.bootable or false) ''
        parted -s "''${${env}}" set ${toString q.index} boot on
      ''}
      ${concatMapStringsSep "" (flag: ''
        parted -s "''${${env}}" set ${toString q.index} ${flag} on
      '') (x.flags or [])}
    ''}
    ${create-f { device = "\"\${${env}}\"-part" + toString q.index; inherit (q) stage; } x.content}
  '';

  create.table = q: x:  ''
    ${helper.find-device q.device}
    ${optionalString (q.stage == 1) ''
      parted -s "''${${helper.device-id q.device}}" mklabel ${x.format}
    ''}
    ${concatStrings (imap (index: create-f (q // { inherit index; })) x.partitions)}
  '';

  mount-f = q: x: mount.${x.type} q x;

  mount.filesystem = q: x: {
    fs.${x.mountpoint} = ''
      if ! findmnt ${q.device} "/mnt${x.mountpoint}" > /dev/null 2>&1; then
        mount ${q.device} "/mnt${x.mountpoint}" -o X-mount.mkdir
      fi
    '';
  };

  mount.devices = q: x: let
    z = foldl' recursiveUpdate {} (mapAttrsToList (name: mount-f { device = "/dev/${name}"; }) x.content);
    # we check for raid after each step, just in case some device contains raids...

    maybeRaid = optionalString (hasAttr "raid" z) (concatStringsSep "\n" (attrValues z.raid));
    # attrValues returns values sorted by name. This is important, because it
    # ensures that "/" is processed before "/foo" etc.
  in ''
    ${optionalString (hasAttr "table" z) (concatStringsSep "\n" (attrValues z.table))}
    ${maybeRaid}

    ${optionalString (hasAttr "luks" z) (concatStringsSep "\n" (attrValues z.luks))}
    ${maybeRaid}

    ${optionalString (hasAttr "lvm" z) (concatStringsSep "\n" (attrValues z.lvm))}
    ${maybeRaid}

    ${optionalString (hasAttr "fs" z) (concatStringsSep "\n" (attrValues z.fs))}
  '';

  mount.mdraid = q: x: (recursiveUpdate (mount-f { device = "/dev/md/${x.name}"; } x.content) {
    raid.all = ''
      mdadm --assemble --scan || true
    '';
  });

  mount.luks = q: x: (
    recursiveUpdate
    (mount-f { device = "/dev/mapper/${x.name}"; } x.content)
    {luks.${q.device} = ''
      cryptsetup luksOpen ${q.device} ${x.name} --key-file ${x.keyfile}
    '';}
  );

  mount.lv = q: x:
    mount-f { device = "/dev/mapper/${q.vgname}-${q.name}"; } x.content;

  mount.lvm = q: x: (
    recursiveUpdate
    (foldl' recursiveUpdate {} (mapAttrsToList (name: mount-f { inherit name; vgname = x.name; }) x.lvs))
    {lvm.${q.device} = ''
      vgchange -a y
    '';}
  );

  mount.noop = q: x: {};

  mount.partition = q: x:
    mount-f { device = "\"\${${q.device}}\"-part" + toString q.index; } x.content;

  mount.table = q: x: (
    recursiveUpdate
    (foldl' recursiveUpdate {} (imap (index: mount-f (q // { inherit index; device = helper.device-id q.device; })) x.partitions))
    {table.${q.device} = helper.find-device q.device;}
  );
}
