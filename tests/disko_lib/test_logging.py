from disko_lib.logging import dedent_start_lines


def test_dedent_start_lines() -> None:
    # Some later lines are indented as much or more than the first line,
    # but they should NOT be dedented!
    raw_lines = """
                    Successfully generated config for some devices.
                    Errors are printed above. The generated partial config is:
                    {
    "disko": {
        "devices": {
        "disk": {
            "MODEL:SanDisk SD8TB8U256G1001,SN:171887425854": {
                "device": "/dev/sdb",
                "type": "disk",
                "content": {
                    "type": "gpt",
                    "partitions": {
                    "UUID:01D60069CEED69C0": {
                        "_index": 1,
                        "size": "523730944",
                        "content": {
                            "type": "filesystem",
                            "format": "ntfs",
                            "mountpoint": null
                        }
    """

    expected_output = """Successfully generated config for some devices.
Errors are printed above. The generated partial config is:
{
    "disko": {
        "devices": {
        "disk": {
            "MODEL:SanDisk SD8TB8U256G1001,SN:171887425854": {
                "device": "/dev/sdb",
                "type": "disk",
                "content": {
                    "type": "gpt",
                    "partitions": {
                    "UUID:01D60069CEED69C0": {
                        "_index": 1,
                        "size": "523730944",
                        "content": {
                            "type": "filesystem",
                            "format": "ntfs",
                            "mountpoint": null
                        }
    """

    lines = raw_lines.splitlines()[1:]
    result = "\n".join(dedent_start_lines(lines))

    assert result == expected_output
