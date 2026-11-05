# SELinux runtime validation in QEMU (Phase 8)

Boots a Linux 3.4.5 kernel built from a **copy** of the pinned GT-I8200 tree on QEMU's ARM Versatile Express board, loads
the Android 7.1.2 SELinux policy (version 30), and checks with real processes what the kernel enforces. Emulator only.
Nothing here runs on, or is built for, the phone's hardware.

## Files
| File | Purpose |
|---|---|
| `make-qemu-kernels.sh` | builds `zImage-k0` (pinned source, SELinux on), `zImage-k1` (+ Google android-3.4 SELinux/LSM code), `zImage-k2` (+ five binder hook calls) in separate copies |
| `init.c` | the test harness (`/init`): freestanding ARM code, raw system calls |
| `gv_qemu_test.te` | TEST-ONLY policy scaffold appended to a copy of the Android policy; removes nothing |
| `execmod/gv_execmod_test.te` | TEST-ONLY scaffold for the libGAL file-type experiment |
| `build-initramfs.py` | writes the cpio initramfs (no external tools) |
| `run-qemu-test.sh` | one QEMU boot, serial console to a log |
| `run-matrix.sh` | builds policies and images and runs all nine runs |

## Needs
git, make, gcc, bison, flex (any), python3, m4; a host-built `checkpolicy` from AOSP `external/selinux` tag `android-7.1.2_r36`
(built with `-fcommon` on gcc 13); the pinned `arm-eabi-4.6` toolchain and the Phase 2 `perl-shim.sh`; the pinned kernel clone at
`44afe4cf6023bf39c18bad72185003a40915fad2` (it is only read); `qemu-system-arm` (Phase 8 used the Ubuntu 24.04 package
`qemu-system-arm` 8.2.2 unpacked with `dpkg -x` into a scratch folder together with its 19 library dependencies, each
checked against the SHA-256 in the archive index, with `LD_LIBRARY_PATH` and `QEMU_DATA_DIR` pointing into that folder).
No root, no installation.

## Steps
```
tools/selinux/qemu/make-qemu-kernels.sh   WORK  PINNED_CLONE  /path/arm-eabi-4.6/bin/arm-eabi-  /path/perl-shim.sh     # about 12 minutes
tools/selinux/qemu/run-matrix.sh  WORK  /path/qemu-system-arm  SYSTEM_SEPOLICY  VENDOR_CM_SEPOLICY  CHECKPOLICY  /path/arm-eabi-4.6/bin/arm-eabi-  OUT
```
Expected summary (see `docs/phase-8-selinux-runtime-validation.md`): run 01 load fails (policyvers 26), runs 02 and 03 load
(policyvers 30), runs 04 and 05 pass 19/19, run 06 passes 14/19 (the five binder denial cases fail, by design), run 07 passes
11/19 (denials vanish in permissive), run 08 passes 3/3, run 09 passes 1/3.
The `zImage` hashes change from build to build (user name and timestamp are embedded).

## How a test works
The harness runs in the `kernel` domain (made permissive by the scaffold; nothing else is). For each test it forks a child that
joins group 3003 (needed by the kernel's paranoid-network check), switches SELinux domain by writing to
`/proc/self/attr/current`, performs one operation, and exits with the result. Exit status 0 means allowed, 13 means `EACCES`,
77 means a binder `BR_FAILED_REPLY`, 100+ and 130+ mean setup failures. A pipe is not used because the pipe would itself be
subject to the policy under test.
