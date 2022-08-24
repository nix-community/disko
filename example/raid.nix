# usage: nix-instantiate --eval --json --strict example/config.nix | jq .
{
  type = "devices";
  content = {
    vdb = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          part-type = "primary";
          start = "1MiB";
          end = "100%";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        }
      ];
    };
    vdc = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          part-type = "primary";
          start = "1MiB";
          end = "100%";
          content = {
            type = "mdraid";
            name = "raid1";
          };
        }
      ];
    };
    raid1 = {
      type = "mdadm";
      level = 1;
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            type = "partition";
            part-type = "primary";
            start = "1MiB";
            end = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/raid";
            };
          }
        ];

      };
    };
  };
}
