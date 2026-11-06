# Phase 9, Part D: compatibility with the real PXA988 kernel

Question: is the Phase 8 back-port suitable for the Samsung GT-I8200 kernel (Linux 3.4.5, pinned commit `44afe4cf6023bf39c18bad72185003a40915fad2`, board config `pxa986_golden_rev02_defconfig`)?

Everything here is **compile-time and static** on disposable copies. The pinned clone was only read. Nothing ran on hardware, and no phone was touched. A kernel that compiles is not a kernel that boots.

Script: `tools/selinux/phase9/make-pxa988-test-kernel.sh` (clones the pinned tree to a scratch directory, applies patches to the copy, builds with the pinned `arm-eabi-4.6` toolchain).

## What the shipped config already contains (STATIC, from the defconfig)

| Option | Value in `pxa986_golden_rev02_defconfig` |
|---|---|
| `CONFIG_SECURITY` | not set |
| `CONFIG_AUDIT` | not set |
| `CONFIG_EXT4_FS_SECURITY` | not set |
| `CONFIG_DEFAULT_SECURITY_DAC` | `y` (`CONFIG_DEFAULT_SECURITY=""`) |
| `CONFIG_ANDROID_BINDER_IPC` | `y` |

So the Samsung kernel as configured has **no SELinux at all** (no LSM, no audit). The question is not "does the patch conflict with Samsung's SELinux", because there is none to conflict with; it is "does enabling SELinux with this patch build and fit". The Samsung binder source contains no SELinux hook calls (Phase 8 added them in a copy).

## Build results (PROVEN, compile only)

| Variant | Config changes on top of the defconfig | zImage | Modules | Warnings in `security/` and `binder.c` (default build) |
|---|---|---|---|---|
| PLAIN | `SECURITY`, `SECURITY_NETWORK`, `AUDIT`, `SECURITY_SELINUX`, `SECURITY_SELINUX_DEVELOP`, `EXT4_FS_SECURITY`, `DEFAULT_SECURITY_SELINUX` on; `DEFAULT_SECURITY_DAC` off | 3,986,008 bytes | 20 `.ko` | 0 |
| SHIP | PLAIN + `SAMSUNG_PRODUCT_SHIP`, `SEC_RESTRICT_ROOTING`, `SEC_RESTRICT_SETUID`, `SEC_RESTRICT_FORK`, `SEC_RESTRICT_ROOTING_LOG` | 3,987,120 bytes | 20 `.ko` | 0 |

Both builds contain the symbols `avc_has_extended_perms`, `security_binder_transaction` and `security_compute_xperms_decision` (checked with `nm` on `vmlinux`). Logs: `docs/build-logs/phase9/40-pxa988-*-summary.log`, `41-pxa988-*-modules-tail.log`.

Notes:
- The zImage sizes are for these scratch builds. They are not release artifacts, were not signed or packaged, and were not compared with the stock image size.
- Enabling `CONFIG_AUDIT` and SELinux is a real config change to the kernel, not just the patch. It was applied to scratch copies only.
- A separate extra-warnings pass (`docs/build-logs/phase9/20-selinux-W1-warnings-in-security-selinux.txt`, 74 lines) lists mostly signed/unsigned comparisons in SELinux files, plus `ioctl_has_perm` missing a prototype (a non-static function added by the patch; same as Google's code). These are style warnings and were not investigated further.

## Conflicts, hooks and Samsung changes

| Check | Result | Label |
|---|---|---|
| Patch applies to the pinned tree | Yes, clean, one whitespace warning | PROVEN |
| Conflict with Samsung SELinux code | None possible: the pinned tree has no SELinux enabled and the patch applies cleanly over the existing `security/selinux` sources | STATIC + PROVEN |
| Binder hooks | Not present in the Samsung binder. `binder-lsm-hooks.patch` adds them, and the Phase 8 patch carries the hook calls too (21 added lines in `binder.c`). Compiles in both variants. | PROVEN (compile) |
| Samsung `SEC_RESTRICT_*` (DAC-based root restriction) | Compiled in SHIP with no conflict. They are independent of SELinux; behaviour together is untested. | PROVEN (compile), UNRESOLVED (runtime) |
| Config dependencies | The seven options above were sufficient. `CONFIG_SECURITY_NETWORK` and `CONFIG_AUDIT` are required by the patch. | PROVEN |
| ARMv7 compile | OK with `arm-eabi-4.6` | PROVEN |
| Samsung-specific kernel on QEMU | Needed three workarounds in the scratch copy (a copied `sec_debug.h`, two stub symbols, `CONFIG_VIBRATOR_ANDROID` off) to boot the Samsung source on vexpress in Phase 8. These stay in scratch; the pinned tree was not changed. | PROVEN (Phase 8) |

## With the 13 follow-up fixes

The 13 applicable follow-ups plus the `kmemdup_nul` adaptation (`tools/selinux/patches/proposed/selinux-followups/`) were built on the vexpress test kernel (k4) and passed the same QEMU tests. They have **not** been rebuilt on the PXA988 config. That is cheap to do with the same script and the patch list, and should be done before any integration. UNRESOLVED (compile on the real config).

## Things this part cannot answer

- Whether the kernel boots with SELinux enabled on the device.
- Whether Samsung's drivers (display, Marvell GPU, modem interface) trip a denial the Android policy does not expect, or whether init `restorecon`/mount labelling works on the device's real filesystems (ext4 labels need `EXT4_FS_SECURITY`; other filesystems on the device were not checked).
- Memory and boot-time cost of the AVC and xperm caches on the device (not measured).
- Lock correctness under the real workload (`CONFIG_PROVE_LOCKING` was not run).
- Whether the Samsung bootloader's kernel command line, ramdisk and signature handling accept this kernel. No firmware or partition data exist.

## Verdict for this part

The back-port is **compatible at build level** with the real board config, with and without Samsung's ship options. It is **not shown to be suitable at runtime**. See `phase-9-final-recommendation.md`.
