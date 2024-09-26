{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
	device = "/dev/sdb";
	content = {
	  type = "gpt";
	  partitions = {
	    crypted2 = {
	      name = "crypt_raidp2";
	      size = "100%";
	      content = {
                type = "luks";
		name = "raidp2"; # this is DM name
	      };
	    };
	  };
	};
      };
      disk1 = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            crypted1 = {
              size = "100%";
	      name = "crypt_raidp1";
              content = {
                type = "luks";
		name = "raidp1";
		content = {
		  type = "btrfs";
		  extraArgs = [ "-f" "-m raid1 -d raid1" "/dev/mapper/raidp2"]; # raidp2 - DM name of 2nd disk
                  subvolumes = {
		    "/" = {
                      mountpoint = "/mnt/SoftWare";
		      mountOptions = [
		        "rw" "relatime" "ssd" "discard=async" "space_cache=v2" "subvolid=5" "subvol=/"
		      ];
		    };
		  };
		};
	      };
	    };
          };
        };
      };
    };
  };
}
