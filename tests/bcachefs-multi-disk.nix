{ pkgs ? import <nixpkgs> { }
, diskoLib ? pkgs.callPackage ../lib { }
}:
diskoLib.testLib.makeDiskoTest {
  testBoot = true;
  inherit pkgs;
  name = "bcachefs-multi";
  disko-config = ../example/bcachefs-multi-disk.nix;
  extraTestScript = ''
    machine.succeed("mountpoint /mnt/pool");
    machine.succeed("lsblk >&2");
  '';
  #   machine.succeed("mountpoint /mnt/pool")
    
  #   # Verify bcachefs mount
  #   machine.succeed("findmnt -t bcachefs")
    
  #   # Check if both devices are part of the pool
  #   out = machine.succeed("bcachefs fs show")
  #   if "vdc" not in out or "vdd" not in out:
  #       raise Exception("Not all devices are part of the bcachefs pool")
        
  #   # Verify device labels and roles
  #   out = machine.succeed("bcachefs device show")
  #   if "fast" not in out or "slow" not in out:
  #       raise Exception("Device labels not set correctly")
    
  #   # Test basic filesystem operations
  #   machine.succeed("touch /mnt/pool/test_file")
  #   machine.succeed("echo 'test content' > /mnt/pool/test_file")
  #   machine.succeed("test -f /mnt/pool/test_file")
  #   content = machine.succeed("cat /mnt/pool/test_file").strip()
  #   if content != "test content":
  #       raise Exception("File content verification failed")
  
  # Required system configuration for bcachefs
  extraInstallerConfig = {
    virtualisation.emptyDiskImages = [ 4096 4096 4096 ];
    boot.supportedFilesystems = [ "bcachefs" ];
  };
  
  extraSystemConfig = {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
