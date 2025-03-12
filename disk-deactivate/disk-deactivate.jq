# since lsblk lacks zfs support, we have to do it this way
def remove:
  if .fstype == "zfs_member" then
    "if type zpool >/dev/null; then zpool destroy -f \(.label); zpool labelclear -f \(.label); fi"
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
      "zpool=$(if type zdb >/dev/null; then zdb -l \(.path) | sed -nr $'s/ +name: \\'(.*)\\'/\\\\1/p'; fi)",
      "if [[ -n \"${zpool}\" ]]; then zpool destroy -f \"$zpool\"; zpool labelclear -f \"$zpool\"; fi",
      "unset zpool"
    ]
  else
    []
  end
;

def deactivate:
  if .type == "disk" or .type == "loop" then
    [
      # If this disk is a member of raid, stop that raid
      "md_dev=$(lsblk \(.path) -l -p -o type,name | awk 'match($1,\"raid.*\") {print $2}')",
      "if [[ -n \"${md_dev}\" ]]; then umount \"$md_dev\"; mdadm --stop \"$md_dev\"; fi",
      # Remove all file-systems and other magic strings
      "wipefs --all -f \(.path)",
      # Remove the MBR bootstrap code
      "dd if=/dev/zero of=\(.path) bs=440 count=1"
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
  elif .type == "swap" then
    [
      "swapoff \(.path)"
    ]
  elif .type == "lvm" then
    (.name | split("-")[0]) as $vgname |
    (.name | split("-")[1]) as $lvname |
    [
      "lvremove -fy \($vgname)/\($lvname)"
    ]
  elif (.type | contains("raid")) then
    [
      "mdadm --stop \(.name)"
    ]
  else
    ["echo Warning: unknown type '\(.type)'. Consider handling this in https://github.com/nix-community/disko/blob/master/disk-deactivate/disk-deactivate.jq"]
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
  "/dev/disk/by-id/\(."id-link")" as $disk_by_id |
  "/dev/disk/by-id/\(.tran)-\(.id)" as $disk_by_id2 |
  "/dev/disk/by-id/\(.tran)-\(.wwn)" as $disk_by_wwn |
  if $disk == $disk_to_clear or $disk_by_id == $disk_to_clear or $disk_by_id2 == $disk_to_clear or $disk_by_wwn == $disk_to_clear then
    [
      "set -fu",
      walk
    ]
  else
    []
  end
;

.blockdevices | map(init) | flatten | join("\n")

