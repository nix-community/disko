use std assert
use std log

use filesystem.nu

def add-type-if-required [partition: record]: record -> record {
    let config = $in

    let type = match ($partition.parttype) {
        'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' => 'EF00' # EFI System
        '21686148-6449-6e6f-744e-656564454649' => 'EF02' # BIOS boot
        _ => null
    }

    if $type == null {
        $config
    } else {
        $config | insert type $type
    }
}

def generate-identifier [partition: record]: record -> string {
    if not (partition.uuid | is-empty) {
        $'UUID:($partition.uuid)...'
    } else {
        $'PARTUUID:($partition.partuuid)'
    }
}

def generate-content [partition: record]: record -> record {
    match ($partition.fstype) {
        # Add filesystems that are more complicated than mkfs
        _ => (filesystem generate-config $partition)
    }
}

export def generate-config [device: record]: nothing -> record {
    assert ($device.pttype == 'gpt') $'BUG! gpt generate-config called with non-gpt device: ($device)'

    log debug $'Generating config for GPT device ($device.path)'

    let partitions = $device.children
    | each { |part|
        {
            ($'UUID:($part.uuid)'): (
                { 
                    size: $part.size,
                    content: (generate-content $part)
                }
                | add-type-if-required $part
            )
        }
    }
    | into record

    {
        type: 'gpt',
        partitions: $partitions
    }
}


export def print-disks []: record -> nothing {
    $in | each { print }
}
