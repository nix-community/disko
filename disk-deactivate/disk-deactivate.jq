# since lsblk lacks zfs support, we have to do it this way
def remove:
  if .fstype == "zfs_member" then
    "zpool destroy -f \(.label)"
  elif .fstype == "LVM2_member" then
    [
      "vg=$(pvs \(.path) --noheadings --options vg_name | grep -o '[a-zA-Z0-9-]*')",
      "vgchange -a n \"$vg\"",
      "vgremove -f \"$vg\""
    ]
  elif .fstype == "swap" then
    "swapoff \(.path)"
  elif .fstype == null then
    # maybe its zfs
    [
      # the next line has some horrible escaping
      "zpool=$(zdb -l \(.path) | sed -nr $'s/ +name: \\'(.*)\\'/\\\\1/p')",
      "if [[ -n \"${zpool}\" ]]; then zpool destroy -f \"$zpool\"; fi",
      "unset zpool"
    ]
  else
    []
  end
;

def deactivate:
  if .type == "disk" then
    [
      "wipefs --all -f \(.path)"
    ]
  elif .type == "part" then
    [
      "wipefs --all -f \(.path)"
    ]
  elif .type == "crypt" then
    [
      "cryptsetup luksClose \(.path)",
      "wipefs --all -f \(.path)"
    ]
  elif .type == "lvm" then
    (.name | split("-")[0]) as $vgname |
    (.name | split("-")[1]) as $lvname |
    [
      "lvremove -fy \($vgname)/\($lvname)"
    ]
  elif .type == "raid1" then
    [
      "mdadm --stop \(.name)"
    ]
  else
    []
  end
;

def walk:
  [
    (.mountpoints[] | select(. != null) | "umount -R \(.)"),
    ((.children // []) | map(walk)),
    remove,
    deactivate
  ]
;

def init:
  "/dev/\(.name)" as $disk |
  if $disk == $disk_to_clear then
    [
      "set -fu",
      walk
    ]
  else
    []
  end
;

.blockdevices | map(init) | flatten | join("\n")

