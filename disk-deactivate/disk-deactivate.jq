def shellquote:
  gsub("'"; "''\\''") |
  "'" + . + "'"
;

# since lsblk lacks zfs support, we have to do it this way
def remove:
  if .fstype == "zfs_member" then
    "if type zpool >/dev/null; then zpool destroy -f \(.label); zpool labelclear -f \(.label); fi"
  elif .fstype == "LVM2_member" then
    [
      # pvs pads its output with whitespace. Only strip that, vg names may contain any of [a-zA-Z0-9+_.-]
      "vg=$(pvs \(.path | shellquote) --noheadings --options vg_name | tr -d '[:space:]')",
      # the name is empty if the pv is not part of a vg
      "if [[ -n \"${vg}\" ]]; then vgchange -a n \"$vg\"; vgremove -f \"$vg\"; fi"
    ]
  elif .fstype == "swap" then
    "swapoff \(.path | shellquote)"
  elif .fstype == null then
    # maybe its zfs
    [
      # the next line has some horrible escaping
      "zpool=$(if type zdb >/dev/null; then zdb -l \(.path | shellquote) | sed -nr $'s/ +name: \\'(.*)\\'/\\\\1/p'; fi)",
      "if [[ -n \"${zpool}\" ]]; then zpool destroy -f \"$zpool\"; zpool labelclear -f \"$zpool\"; fi",
      "unset zpool"
    ]
  else
    []
  end
;

# Split the device-mapper name of a logical volume into its vg and lv name.
# The name is "<vg>-<lv>[-<layer>]", where every "-" inside the vg and lv name is doubled.
# Neither name can start with a "-", so the first single "-" is the separator.
def lvm_names:
  capture("^(?<vg>[^-](?:[^-]|--)*)-(?<lv>[^-](?:[^-]|--)*)") |
  map_values(gsub("--"; "-"))
;

def deactivate:
  if .type == "disk" or .type == "loop" then
    [
      # If this disk is a member of raid, stop that raid
      "md_dev=$(lsblk \(.path | shellquote) -l -p -o type,name | awk 'match($1,\"raid.*\") {print $2}')",
      "if [[ -n \"${md_dev}\" ]]; then umount \"$md_dev\"; mdadm --stop \"$md_dev\"; fi",
      # Remove all file-systems and other magic strings
      "wipefs --all -f \(.path | shellquote)",
      # Remove the MBR bootstrap code
      "dd if=/dev/zero of=\(.path | shellquote) bs=440 count=1"
    ]
  elif .type == "part" then
    [
      "wipefs --all -f \(.path | shellquote)"
    ]
  elif .type == "crypt" then
    [
      "cryptsetup luksClose \(.path | shellquote)",
      "wipefs --all -f \(.path | shellquote)"
    ]
  elif .type == "swap" then
    [
      "swapoff \(.path | shellquote)"
    ]
  elif .type == "lvm" then
    [
      (.name | lvm_names | "lvremove -fy \("\(.vg)/\(.lv)" | shellquote)")
    ]
  elif (.type | contains("raid")) then
    [
      "wipefs --all -f \(.path | shellquote)",
      "mdadm --stop \(.name | shellquote)"
    ]
  else
    ["echo Warning: unknown type '\(.type)'. Consider handling this in https://github.com/nix-community/disko/blob/master/disk-deactivate/disk-deactivate.jq"]
  end
;

def walk:
  [
    (.mountpoints[] | select(. != null) | "umount -R \(. | shellquote)"),
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
