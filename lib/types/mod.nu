export use gpt.nu

# To see what other fields are available in the lsblk output and what
# sort of values you can expect from them, run:
# lsblk -O | less -S
const lsblk_output_fields = [
    ID-LINK,
    FSTYPE,
    FSSIZE,
    FSUSE%,
    KNAME,
    LABEL,
    MODEL,
    PARTFLAGS,
    PARTLABEL,
    PARTN,
    PARTTYPE,
    PARTTYPENAME,
    PARTUUID, # The UUID used for /dev/disk/by-partuuid
    PATH,
    PHY-SEC,
    PTTYPE,
    REV,
    SERIAL,
    SIZE,
    START,
    MOUNTPOINT, # Canonical mountpoint
    MOUNTPOINTS, # All mountpoints, including e.g. bind mounts
    TYPE,
    UUID, # The UUID used for /dev/disk/by-uuid, if available
]

export def list-block-devices []: nothing -> table {
    ^lsblk --output ($lsblk_output_fields | str join ',') --json --tree
    | from json
    | $in.blockdevices
}

def generate-content [device: record] nothing -> record {
    match $device.pttype {
        gpt => (gpt generate-config $device)
        _ => { errors: [ { code: ERR_UNSUPPORTED_PARTITION_TABLE_TYPE, details: { pttype: $device.pttype } } ] }
    }

}

export def generate-config [block_devices?: table]: nothing -> record {
    let block_devices = $block_devices | default (list-block-devices)

    let disks = $block_devices
    | each { |device|
        {
            ($'MODEL:($device.model),SN:($device.serial)'):{
                device: $device.kname,
                type: $device.type,
                content: (generate-content $device)
            }
        }
    }
    | into record

    return {
        success: true,
        value: {
            disk: $disks 
            # TODO: Add lvm_vg, mdadm, nodev and zpool
        }
    }
}


export def print-disks []: record -> nothing {
    $in | each { print }
}
