# Running and debugging tests

Disko makes extensive use of VM tests. All examples you can find in
[the example directory](../example) have a respective test suite that verifies
the example is working in [the tests directory](../tests/). They utilize the
[NixOS test functionality](https://nixos.org/manual/nixos/stable/#sec-nixos-tests).

We use a wrapper around this called `makeDiskoTest`. There is currently (as of
2024-10-16) no documentation for all its arguments, but you can have a look at
[its current code](https://github.com/nix-community/disko/blob/master/lib/tests.nix#L44C5-L58C10),
that should already be helpful.

However, you don't need to know about all of the inner workings to interact with
the tests effectively. For some of the most common operations, see the sections
below.

## Run just one of the tests

```sh
nix build --no-link .#checks.x86_64-linux.simple-efi
```

This will run the test in [`tests/simple-efi.nix`](../tests/simple-efi.nix),
which builds a VM with all disks specified in the
[`example/simple-efi.nix`](../example/simple-efi.nix) config connected as
virtual devices, run disko to format them, reboot, verify the VM boots properly,
and then run the code specified in `extraTestScript` to validate that the
partitions have been created and were mounted as expected.

### How `extraTestScript` works

This is written in Python. The most common lines you'll see look something like
this:

```python
machine.succeed("test -b /dev/md/raid1");
machine.succeed("mountpoint /");
```

The `machine` in these is a machine object, which defines
[a multitude of functions to interact with and test](https://nixos.org/manual/nixos/stable/#ssec-machine-objects),
assumptions about the state of the VM after formatting and rebooting.

Disko currently (as of 2024-10-16) doesn't have any tests that utilize multiple
VMs at once, so the only machine available in these scripts is always just the
default `machine`.

## Debugging tests

If you make changes to disko, you might break a test, or you may want to modify
a test to prevent regressions. In these cases, running the full test with
`nix build` every time is time-consuming and tedious.

Instead, you can build and then run the VM for a test in interactive mode. This
will create the VM and all virtual disks as required by the test's config, but
allow you to interact with the machine on a terminal afterwards.

First, build the interactive test driver:

```
nix build .#checks.x86_64-linux.simple-efi.driverInteractive
```

The build outputs will be linked in the "result" directory. Of interest will be
the generated Python "test-script" it contains, which will contain the commands
that the test driver will run.

You can run the test driver with:
```
result/bin/nixos-test-driver --keep-vm-state
```

This will open an IPython prompt in which you can use the same objects and
functions as in `extraTestScript`.

In there, you can debug the test-script, by copy-pasting and running (parts of)
its contents into the prompt. This will, for example, allow you to inspect the
VM state after running each of the generated "disko-format", "disko-mount",
"disko-destroy-format-mount", etc. scripts.

From the prompt, you can also run:

```
machine.shell_interact()
```

to start the VM and attach the terminal to it. This will also open a QEMU
window, in which you can log in as `root` with no password, but that makes it
more difficult to paste input and output. Instead, wait for the systemd messages
to settle down, and then **simply start typing**. This should make a `$` prompt
appear, indicating that the machine is ready to take commands. The NixOS manual
calls out a few special messages to look for, but these are buried underneath
the systemd logs.

Once you are in this terminal, you're running commands on the VM. The only thing
that doesn't work here is the `exit` command. Instead, you need to press Ctrl+D
and wait for a second to return to the IPython prompt.

In summary, a full session looks something like this:

```
# nix build .#checks.x86_64-linux.simple-efi.driverInteractive
# result/bin/nixos-test-driver --keep-vm-state 
start all VLans
start vlan
running vlan (pid 146244; ctl /tmp/vde1.ctl)
(finished: start all VLans, in 0.00 seconds)
additionally exposed symbols:
    machine,
    vlan1,
    start_all, test_script, machines, vlans, driver, log, os, create_machine, subtest, run_tests, join_all, retry, serial_stdout_off, serial_stdout_on, polling_condition, Machine
>>> machine.shell_interact()
machine: waiting for the VM to finish booting
machine: starting vm
machine: QEMU running (pid 146286)
machine # [    0.000000] Linux version 6.6.48 (nixbld@localhost) (gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) #1-NixOS SMP PREEMPT_DYNAMIC Thu Aug 29 15:33:59 UTC 2024
machine # [    0.000000] Command line: console=ttyS0 panic=1 boot.panic_on_fail clocksource=acpi_pm loglevel=7 net.ifnames=0 init=/nix/store/0a52bbvxr5p7xijbbk17qqlk8xm4790y-nixos-system-machine-test/init regInfo=/nix/store/3sh5nl75bnj1jg87p5gcrdzs0lk154ma-closure-info/registration console=ttyS0
machine # [    0.000000] BIOS-provided physical RAM map:
...
... more systemd messages
...
machine # [    6.135577] dhcpcd[679]: DUID 00:01:00:01:2e:a2:74:e6:52:54:00:12:34:56
machine # [    6.142785] systemd[1]: Finished Kernel Auditing.
machine: Guest shell says: b'Spawning backdoor root shell...\n'
machine: connected to guest root shell
machine: (connecting took 6.61 seconds)
(finished: waiting for the VM to finish booting, in 6.99 seconds)
machine: Terminal is ready (there is no initial prompt):
machine # [    6.265451] 8021q: 802.1Q VLAN Support v1.8
machine # [    6.186797] nsncd[669]: Oct 16 13:11:55.010 INFO started, config: Config { ignored_request_types: {}, worker_count: 8, handoff_timeout: 3s }, path: "/var/run/nscd/socket"
...
... more systemd messages
...
machine # [   12.376900] systemd[1]: Reached target Host and Network Name Lookups.
machine # [   12.379265] systemd[1]: Reached target User and Group Name Lookups.
$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
fd0      2:0    1    4K  0 disk 
sr0     11:0    1 1024M  0 rom  
vda    253:0    0    1G  0 disk /
vdb    253:16   0    4G  0 disk 
├─vdb1 253:17   0  500M  0 part 
└─vdb2 253:18   0  3.5G  0 part
```

You can find some additional details in
[the NixOS manual's section on interactive testing](https://nixos.org/manual/nixos/stable/#sec-running-nixos-tests-interactively).

## Running all tests at once

If you have a bit of experience, you might be inclined to run `nix flake check`
to run all tests at once. However, we instead recommend using
[nix-fast-build](https://github.com/Mic92/nix-fast-build). The reason for this
is that each individual test takes a while to run, but only uses <=4GiB of RAM
and a limited amount of CPU resources. This means they can easily be evaluated
and run in parallel to save time, but `nix` doesn't to that, so a full test run
takes >40 minutes on a mid-range system. With `nix-fast-build` you can scale up
the number of workers depending on your system's capabilities. It also utilizes
[`nix-output-monitor`](https://github.com/maralorn/nix-output-monitor) to give
you a progress indicator during the build process as well. For example, on a
machine with 16GB of RAM, this gives you a 2x speed up without clogging your
system:

```sh
nix shell nixpkgs#nix-fast-build
nix-fast-build --no-link -j 2 --eval-workers 2 --flake .#checks
```

You can try higher numbers if you want to. Be careful with scaling up
`--eval-workers`, each of these will use 100% of a CPU core and they don't leave
any time for hyperthreading, so 4 workers will max out a a CPU with 4 cores and
8 threads, potentially rendering your system unresponsive! `-j` is less
dangerous to scale up, but you probably don't want to go higher than
`(<ram in your system> - 4GB)/4GB` to prevent excessive swap usage, which will
would slow down the test VMs to a crawl.
