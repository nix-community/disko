
export def generate-config [partition: record] {
    assert ($partition.type == 'part') $'BUG! filesystem generate-config called with non-partition: ($partition)'

    {
        type: 'filesystem',
        format: $partition.fstype,
        mountpoint: $partition.mountpoint,
    }
}