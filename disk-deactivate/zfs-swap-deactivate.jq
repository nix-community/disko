def turnOffSwaps:
    if (.name | test("^zd[0-9]+$")) and .type == "disk" then
        "swapoff /dev/" + .name
    else
        []
    end
;

.blockdevices | map(turnOffSwaps) | flatten | join("\n")

