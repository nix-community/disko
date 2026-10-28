{
  pkgs ? import <nixpkgs> { },
  diskoLib ? pkgs.callPackage ../lib { },
  lib ? pkgs.lib,
}:
let
  generator = pkgs.callPackage ../. { checked = true; };

  mkDisk = content: {
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/vdb";
      content = {
        type = "gpt";
        partitions = content;
      };
    };
  };

  mkBcache =
    {
      partitions,
      bcache ? {
        main = {
          type = "bcache";
          device = "/dev/bcache0";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      },
    }:
    let
      diskConfig = mkDisk partitions;
    in
    {
      disko.devices = diskConfig.disko.devices // {
        inherit bcache;
      };
    };

  scriptEvaluates = config: (builtins.tryEval (generator._cliMount config pkgs).drvPath).success;
  configEvaluates =
    config: (builtins.tryEval (builtins.deepSeq (generator.config config) true)).success;
  evaluates = config: (scriptEvaluates config) && (configEvaluates config);

  invalidCases = {
    missing-cache = mkBcache {
      partitions.backing = {
        size = "100%";
        content = {
          type = "bcache_backing";
          set = "main";
        };
      };
    };

    missing-backing = mkBcache {
      partitions.cache = {
        size = "100%";
        content = {
          type = "bcache_cache";
          set = "main";
        };
      };
    };

    cache-undefined-set = mkBcache {
      bcache = { };
      partitions.cache = {
        size = "100%";
        content = {
          type = "bcache_cache";
          set = "missing";
        };
      };
    };

    backing-undefined-set = mkBcache {
      bcache = { };
      partitions.backing = {
        size = "100%";
        content = {
          type = "bcache_backing";
          set = "missing";
        };
      };
    };

    duplicate-cache = mkBcache {
      partitions = {
        cache-a = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        cache-b = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    duplicate-backing = mkBcache {
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing-a = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
        backing-b = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    duplicate-device = mkBcache {
      bcache = {
        main = {
          type = "bcache";
          device = "/dev/bcache0";
        };
        other = {
          type = "bcache";
          device = "/dev/bcache0";
        };
      };
      partitions = {
        cache-main = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing-main = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
        cache-other = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "other";
          };
        };
        backing-other = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "other";
          };
        };
      };
    };

    invalid-device-path = mkBcache {
      bcache.main = {
        type = "bcache";
        device = "/dev/disk/by-id/not-supported";
      };
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    duplicate-cache-same-device = mkBcache {
      partitions = {
        cache-a = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-cache";
          };
        };
        cache-b = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-cache";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    duplicate-backing-same-device = mkBcache {
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing-a = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-backing";
          };
        };
        backing-b = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-backing";
          };
        };
      };
    };

    same-cache-and-backing-device = mkBcache {
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-member";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-member";
          };
        };
      };
    };

    member-device-not-absolute = mkBcache {
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "cache0";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    member-device-is-bcache-output = mkBcache {
      partitions = {
        cache = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/bcache0";
          };
        };
        backing = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
      };
    };

    reused-cache-across-sets = mkBcache {
      bcache = {
        main = {
          type = "bcache";
          device = "/dev/bcache0";
        };
        other = {
          type = "bcache";
          device = "/dev/bcache1";
        };
      };
      partitions = {
        cache-main = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-cache";
          };
        };
        backing-main = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
        cache-other = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "other";
            device = "/dev/disk/by-partlabel/shared-cache";
          };
        };
        backing-other = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "other";
          };
        };
      };
    };

    reused-backing-across-sets = mkBcache {
      bcache = {
        main = {
          type = "bcache";
          device = "/dev/bcache0";
        };
        other = {
          type = "bcache";
          device = "/dev/bcache1";
        };
      };
      partitions = {
        cache-main = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
          };
        };
        backing-main = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-backing";
          };
        };
        cache-other = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "other";
          };
        };
        backing-other = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "other";
            device = "/dev/disk/by-partlabel/shared-backing";
          };
        };
      };
    };

    reused-cache-as-backing = mkBcache {
      bcache = {
        main = {
          type = "bcache";
          device = "/dev/bcache0";
        };
        other = {
          type = "bcache";
          device = "/dev/bcache1";
        };
      };
      partitions = {
        cache-main = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "main";
            device = "/dev/disk/by-partlabel/shared-member";
          };
        };
        backing-main = {
          size = "1G";
          content = {
            type = "bcache_backing";
            set = "main";
          };
        };
        cache-other = {
          size = "1G";
          content = {
            type = "bcache_cache";
            set = "other";
          };
        };
        backing-other = {
          size = "100%";
          content = {
            type = "bcache_backing";
            set = "other";
            device = "/dev/disk/by-partlabel/shared-member";
          };
        };
      };
    };
  };

  validCase = mkBcache {
    partitions = {
      cache = {
        size = "1G";
        content = {
          type = "bcache_cache";
          set = "main";
        };
      };
      backing = {
        size = "100%";
        content = {
          type = "bcache_backing";
          set = "main";
        };
      };
    };
  };

  validTwoSets = mkBcache {
    bcache = {
      main = {
        type = "bcache";
        device = "/dev/bcache0";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/main";
        };
      };
      other = {
        type = "bcache";
        device = "/dev/bcache1";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/other";
        };
      };
    };
    partitions = {
      cache-main = {
        size = "1G";
        content = {
          type = "bcache_cache";
          set = "main";
        };
      };
      backing-main = {
        size = "1G";
        content = {
          type = "bcache_backing";
          set = "main";
        };
      };
      cache-other = {
        size = "1G";
        content = {
          type = "bcache_cache";
          set = "other";
        };
      };
      backing-other = {
        size = "100%";
        content = {
          type = "bcache_backing";
          set = "other";
        };
      };
    };
  };

  failedInvalidCases = lib.filterAttrs (_: evaluates) invalidCases;
  failedInvalidConfigCases = lib.filterAttrs (_: configEvaluates) invalidCases;
  validMountScript = generator._cliMount validCase pkgs;
  validFormatScript = generator._cliFormat validCase pkgs;
  validUnmountScript = generator._cliUnmount validCase pkgs;
  validDestroyScript = generator._cliDestroy validCase pkgs;
in
pkgs.runCommand "bcache-validation" { } ''
  grep=${pkgs.gnugrep}/bin/grep
  mount_script=${lib.getExe validMountScript}
  format_script=${lib.getExe validFormatScript}
  unmount_script=${lib.getExe validUnmountScript}
  destroy_script=${lib.getExe validDestroyScript}

  ${lib.optionalString (failedInvalidCases != { }) ''
    echo "Expected invalid bcache configs to fail evaluation: ${lib.concatStringsSep ", " (lib.attrNames failedInvalidCases)}" >&2
    exit 1
  ''}
  ${lib.optionalString (failedInvalidConfigCases != { }) ''
    echo "Expected invalid bcache configs to fail config evaluation: ${lib.concatStringsSep ", " (lib.attrNames failedInvalidConfigCases)}" >&2
    exit 1
  ''}
  ${lib.optionalString (!(evaluates validCase)) ''
    echo "Expected valid bcache config to evaluate" >&2
    exit 1
  ''}
  ${lib.optionalString (!(evaluates validTwoSets)) ''
    echo "Expected valid two-set bcache config to evaluate" >&2
    exit 1
  ''}
  "$grep" -q 'bcache_cache_main' "$mount_script"
  "$grep" -q 'bcache_backing_main' "$mount_script"
  "$grep" -q 'bcache-super-show' "$mount_script"
  "$grep" -q '/sys/fs/bcache/register' "$mount_script"
  "$grep" -q 'backing_dev_name' "$mount_script"
  "$grep" -q 'make-bcache' "$format_script"
  "$grep" -q 'register_bcache_member' "$format_script"
  "$grep" -q 'bcache_release_members' "$format_script"
  "$grep" -q 'is not attached to cache set' "$format_script"
  "$grep" -q 'is not attached to cache set' "$mount_script"
  "$grep" -q 'bcache_release_members' "$destroy_script"
  # Unmount must never detach (drops the cache from the backing superblock)
  # and teardown must never unregister unrelated cache sets.
  for script in "$mount_script" "$unmount_script" "$format_script" "$destroy_script"; do
    if "$grep" -qE 'bcache/detach|find /sys/fs/bcache' "$script"; then
      echo "$script detaches bcache or unregisters all cache sets" >&2
      exit 1
    fi
  done
  "$grep" -q 'backing_dev_name' "$format_script"
  "$grep" -q 'uses the same block device for cache and backing' "$format_script"
  if "$grep" -q 'make-bcache' "$mount_script"; then
    echo "Mount-only script must not run make-bcache" >&2
    exit 1
  fi
  touch "$out"
''
