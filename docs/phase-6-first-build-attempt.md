# Phase 6: first experimental build preparation and attempt

Computer-only. No phone contact, nothing flashed, **kernel source not modified**, no proprietary file in the repository, and the rooted community dump was not used as firmware. No security feature was disabled to get anything through; where Android needs one, it is listed as a decision for the owner.

## 1. Answers to the required questions

| Question | Answer |
|---|---|
| Did the build start? | **No.** `tools/build/build-lineage.sh` stopped at its first gate (preflight). Nothing was synced or compiled as an Android build. |
| Did it complete? | No. |
| First blocking error | **Disk space:** 18 GiB free on this machine. A measured sample of just three projects at depth 1 (`frameworks/base` 2.4 GiB, prebuilt clang 0.7 GiB, host gcc 0.3 GiB = 3.4 GiB) shows a full 479-project tree plus build output cannot fit. This is the first gate in the log; it would have been the first failure of a real attempt. |
| Other blockers found (all independent of disk) | Host is not a supported Android 7 build host: JDK 21 (needs OpenJDK 8), no python2 (the build's release tools are Python 2 source), no `repo` installed. Missing inputs: no verified official firmware, so no vendor tree; no verified boot image values or partition sizes; no out-of-band kernel build with SELinux. See sections 3 to 6. |
| Components that compiled | None as part of an Android build. Smoke tests only, listed in section 7. |
| Missing proprietary files | All of them: the vendor tree has 0 extracted files. See section 5. |
| Unresolved graphics and SELinux issues | Section 6. SELinux has a **fundamental** blocker (kernel/policy version). |
| Safe for later controlled testing? | **No, not yet.** There are fundamental blockers (SELinux, no verified firmware or partition data). Nothing built here is a candidate for any device. |
| Phase 7 | Section 9. |

A successful compile of any of these pieces would not show that the ROM boots or that hardware works. Nothing here claims that.

## 2. Audit

Logs are in [build-logs/phase6/](build-logs/phase6/).

### Repository, manifest and pinned revisions
- Branch `ccr-a52c2634-s7v35o`, starting at `7ac0cc6`. Working tree clean before this phase.
- `tools/build/verify-pins.sh` fetches every revision in `local_manifest.xml` into a throwaway repository and prints its tree ID ([01-verify-pins.log](build-logs/phase6/01-verify-pins.log)): all 4 exist.

| Path | Revision | Tree | Note |
|---|---|---|---|
| kernel (Koloses `kernel_i8200`) | `44afe4cf…` | `0eebf6f9…` (matches Phase 2) | 2016-03-05 |
| `arm-eabi-4.6` toolchain (AOSP) | `d73a051b…` | `bb9221b9…` | 2012-04-24 |
| `hardware/marvell/wlan` (LineageOS) | `d00e9517…` | `d0131866…` | 2021-03-18 |
| `hardware/marvell/bt` (LineageOS) | `f4b89114…` | `66e96162…` | 2025-09-22 |

- LineageOS `android` manifest, branch `cm-14.1` at `3053abb1…`: 479 projects, AOSP tag `android-7.1.2_r36`. The full list of revisions used for analysis, plus tool versions, is in [07-exact-revisions.tsv](build-logs/phase6/07-exact-revisions.tsv). The analysis clones are branch tips fetched on 2026-11-05; a real sync would be recorded with `repo manifest -r` (the driver script does this).
- The community device repositories were not added to the manifest (they are reference only).

### Build environment (`tools/build/preflight.sh`, [00-preflight.log](build-logs/phase6/00-preflight.log))
| Gate | Result |
|---|---|
| Disk (planning figure 100 GiB) | FAIL, 18 GiB free |
| OpenJDK 8 | FAIL, JDK 21 |
| python2 | FAIL, absent |
| `repo` | FAIL, not installed (installing system-wide needs your approval; I did not) |
| Pinned revisions exist | PASS (4 of 4) |
| Vendor tree from verified firmware | FAIL |
| Out-of-band kernel (zImage + modules) | FAIL |
| Kernel has SELinux | FAIL |
| BoardConfig values defined | FAIL (boot base, page size, partition sizes, flash block size) |

The machine also has 4 CPUs and 15 GiB RAM, below what a full Android 7 build is normally given; not a hard blocker on its own.

### Reachability
`android.googlesource.com`, the `repo` tool bucket and the LineageOS and Koloses repositories were all reachable through `git` from this environment. So a sync is possible in principle with enough disk on a supported host. Samsung's servers remain blocked, as in earlier phases.

## 3. Build-system fixes made (documented, well understood)

All verified by reading cm-14.1 sources and by loading the real cm-14.1 build system in a scratch tree (section 7).

1. **Kernel wiring.** Lineage's `kernel.mk` (`vendor/cm`) only accepts `TARGET_PREBUILT_KERNEL` if the `TARGET_KERNEL_SOURCE` directory does **not exist**, and otherwise always builds out of tree. The Koloses tree contains 899 committed build leftovers that make Kbuild refuse out-of-tree builds (Phase 2). Cleaning them would modify the kernel source, so instead:
   - `local_manifest.xml` now fetches the pinned kernel to `kernel/samsung/goldenvess3g-src` (a provenance record that Lineage does not build from).
   - `BoardConfig.mk` keeps `TARGET_KERNEL_SOURCE` at the absent path and sets `TARGET_PREBUILT_KERNEL` from `GOLDENVESS3G_KERNEL_DIR` (an out-of-band build with `tools/kernel-build/build-golden-kernel.sh`).
   - `device.mk` copies `modules/*.ko` from that directory to `/system/lib/modules`. Nothing from it is committed.
   - `KERNEL_TOOLCHAIN` is now set to the pinned `arm-eabi-4.6` (without it `kernel.mk` would use the bare prefix `arm-eabi-` from `PATH`).
   Which kernel variant and config to ship is **not** chosen.
2. **Build guards** (`build-guards.mk`, included from a new `Android.mk`). The build refuses to run, with a message naming the missing item, unless: boot image base, page size and command line, boot/recovery/system/userdata partition sizes and flash block size are set; the vendor makefile and `extraction-report.txt` exist; `GOLDENVESS3G_KERNEL_DIR` is set; and its `.config` has `CONFIG_SECURITY_SELINUX=y`. Without them Android would silently use mkbootimg defaults, skip image-size checks and build without GPU libraries. There is no override switch. Tested with synthetic dummy values in a scratch tree ([06-guards-and-kernel-wiring.log](build-logs/phase6/06-guards-and-kernel-wiring.log)): each guard fires in turn, and the last case passes. The dummy values exist only in that scratch probe.
3. **Vendor manifest:** `STUpdateTool` and `rtccd2` excluded, `libacdapi_clb.so` added (Phase 5), re-checked with the generator.
4. **RIL interposer:** `<stdio.h>` is now included only on non-Android builds, so the Android build does not pull in a header that clang 18 rejects in N's bionic. Behaviour unchanged; host test still passes.
5. **Breakfast naming checked:** cm-14.1 `breakfast` tries `lineage_<device>` first, then `cm_<device>`, so `lineage_goldenvess3g.mk` is found without a `vendorsetup.sh`.

Not changed: nothing was applied to bionic, sepolicy or the kernel.

## 4. Source dependencies still missing or unverified

| Item | State |
|---|---|
| Android source tree | Not synced (disk). |
| Device and vendor repositories | Exist only as `android/` in this repository; no hosted repository. |
| Kernel image with the right config | None. The Phase 2 images are from the plain defconfig (no SELinux). |
| Boot image header values | Unverified (community values conflict). |
| Partition table and sizes | Unknown. |
| Official firmware | Not obtainable from this environment. |
| Recovery | Out of scope, but the OTA zip build includes a recovery image, so its partition size is also required. |

## 5. Proprietary files

`vendor/samsung/goldenvess3g/proprietary/` holds 0 files and there is no `extraction-report.txt`. The manifest lists 201 active entries. The rooted community dump is **not** accepted: the extraction script refuses anything without `PROVENANCE.txt` from Samsung's own update server or open-source package, and the guards above stop the build without the extraction report. All the following groups are therefore missing: GPU/EGL/gralloc/HWC (`libGAL`, `libEGL_MRVL`, `gralloc.mrvl`, `hwcomposer.mrvl`, `libHWComposerGC`, `libgcu`, `libgputex` and others), Wi-Fi/Bluetooth firmware and tools, audio HAL and effects, sensors HAL and `libacdapi_clb`, GPS HAL, power HAL, platform support libraries, and (out of the first scope) camera and telephony files.

## 6. Graphics and SELinux

### libGAL.so
- Android 7's linker allows a text-relocation library only when the process's target SDK is the platform value or at most 22. Apps targeting SDK 23 or newer that load `libGAL.so` through `libEGL_MRVL` would be refused even with `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS` (SOURCE, bionic `linker.cpp`; Phase 5).
- I wrote a minimal proposal, `patches/bionic-libGAL-textrel.patch`: inert unless a board sets `GOLDENVESS3G_LIBGAL_TEXTREL := true`, and when set it exempts exactly `/system/lib/libGAL.so`. It applies cleanly to the cm-14.1 bionic (`git apply --check`, [04-libGAL-patch-check.log](build-logs/phase6/04-libGAL-patch-check.log)). **It is not applied, not built and not wired into any board setting.** It is similar in effect to the SM-T110 port's patch, written independently.
- Why not applied: it weakens a platform rule (needs your decision and a security review), and it only helps if SELinux can grant the needed `execmod` (next section). Without the real firmware there is no `libGAL.so` to test it against.
- Remaining graphics unknowns (unchanged from Phase 5): HWC version acceptance by SurfaceFlinger, `getCallingPid` forwarder wiring, composer layer layout, galcore parameters. All run-time.

### SELinux
Findings (SOURCE: cm-14.1 `system/core/init`, `system/sepolicy` at `83840c7f`; kernel config and pinned kernel source):
1. **The kernel has no SELinux.** The plain defconfig has `CONFIG_SECURITY` unset (also `CONFIG_AUDIT` and `CONFIG_EXT4_FS_SECURITY`). Android 7's init loads a policy and calls `security_failure()` if that fails, so **a kernel from the plain defconfig cannot start Android 7.1.2.** This corrects the Phase 4 wording that treated SELinux as an optional choice.
2. **Policy version mismatch (fundamental).** The kernel's SELinux accepts policy versions up to **26** and contains **no** ioctl extended-permission code (0 occurrences of `xperm` in `security/selinux`). Android 7.1.2's policy is built at version **30** by default and the platform policy files use `allowxperm` and `neverallowxperm` (`domain.te`, `mediaserver.te`, `priv_app.te` and others). Raising the kernel's maximum by configuration is not enough because the code for the feature is absent.
3. **Text relocations need policy.** With the flag set, `domain.te` allows device rules granting `execmod` on `system_file`. A dedicated type for `libGAL.so` would still violate the neverallow. So the exception would be broad (any domain granted it).
4. **The reference port runs with SELinux off.** The SM-T110 repository (`jakaco/lineageos-14.1-goyawifi`) carries a `system-core.patch` that makes init skip SELinux entirely (a bring-up macro) and boots with `selinux=0 androidboot.selinux=disabled`. Its README says SELinux remains disabled. That matches finding 2: it is the shortcut around exactly this blocker.

Options (none applied; all need your decision):

| Option | What it takes | Cost |
|---|---|---|
| A. Back-port xperm support into the kernel, enable SELinux, build policy at v30 | A kernel source patch series (separate approval, review, new Phase 2-style verification) | Largest effort; keeps the security model. |
| B. Strip `allowxperm` rules from the platform policy, build at v26 | Policy changes; unverified that the rest compiles at v26 and that Android 7 services still work | Medium effort; weakens policy in ways that need review. |
| C. Run without SELinux (init patch, as the SM-T110 port) | An init patch and command-line settings | Small effort; disables a core Android security feature. Only as an explicit owner decision for a bring-up build. |

I did not choose, and `build-guards.mk` refuses a kernel without SELinux so C cannot happen silently.

## 7. What compiled or loaded (all smoke tests, none is a ROM build)

| Item | Method | Result | Log |
|---|---|---|---|
| Shim sources (VectorImpl stubs, RefBase stub, getCallingPid forwarder) | `arm-eabi-g++/gcc` 4.6, ARMv7 NEON, `-Wall -Wextra -Werror -c` | Compile; `nm` shows the 16 + 2 expected exported symbol names. Android 7 itself builds with clang, so this checks source validity only. | [02-shim-compile.log](build-logs/phase6/02-shim-compile.log) |
| RIL interposer | `clang-18 --target=armv7a-linux-androideabi -fsyntax-only` against cm-14.1 bionic/core/ril headers (scratch pre-include for a clang-18 vs old-bionic header mismatch) | No diagnostics | [03-interposer-compile.log](build-logs/phase6/03-interposer-compile.log) |
| RIL interposer logic | Host build with a fake vendor RIL | Pass (ids 1 to 123 forwarded, 124 to 137 rejected, none forwarded) | Phase 5 test, rerun |
| libGAL linker patch | `git apply --check` on cm-14.1 bionic | Applies | [04](build-logs/phase6/04-libGAL-patch-check.log) |
| Product and board files | The real cm-14.1 `build/core/config.mk` and `vendor/cm` loaded in a scratch tree with only `build`, `vendor/cm` and our device directory | Resolve `lineage_goldenvess3g`: `TARGET_DEVICE=goldenvess3g`, arch `arm`, `armv7-a-neon`, board platform `mrvl`, kernel config name, 63 copy-file entries, Marvell Wi-Fi/Bluetooth flags, text-relocation flag; the five local copy-file sources exist. Needed a scratch fake JDK directory to get past the JDK check (not used for anything else). The other 58 copy-file entries point at other repositories and were not checked. | [05](build-logs/phase6/05-minitree-product-config.log) |
| Kernel | Not rebuilt. Phase 2 result stands: kernel and 20 modules from the pinned source. | n/a | Phase 2 |

## 8. Reproducibility record

- Driver: `tools/build/build-lineage.sh TREE LOGDIR` (gate 0 preflight; `repo init -b cm-14.1`, local manifest, `repo sync -c`, `repo manifest -r`, device/vendor copy, `breakfast`, `mka bacon`). It stops at the first failed gate and writes complete logs. It was run: it stopped at gate 0 ([build-driver.log](build-logs/phase6/build-driver.log)). The log contains two entries because it was run twice (the second time after the kernel and SELinux gates were added).
- Pre-checks: `tools/build/verify-pins.sh`, `tools/build/preflight.sh`.
- Revisions and tool versions: [07-exact-revisions.tsv](build-logs/phase6/07-exact-revisions.tsv).
- Configuration used: the committed `android/` tree at the commit of this phase; no environment overrides.

## 9. Phase 7 should investigate

1. **SELinux decision (first).** Prepare option A and B facts without touching the kernel: compile the N platform policy with `checkpolicy` at version 26 on the host to see what breaks (not run here; I did not build `checkpolicy`), and scope an xperm back-port against kernel 3.4.5 as a written plan. Then get the owner's decision.
2. **Official firmware and the partition table.** Needs Samsung access or user-supplied files with hashes. Then: run `extract-files.sh`, re-run the ELF, text-relocation and dlopen audits, extract boot image header values and partition sizes from the stock images, and fill the guarded BoardConfig values from those only.
3. **A supported build host.** An environment with at least a few hundred GiB, OpenJDK 8, Python 2 and a make version the Android 7 tree accepts, or a container image for that. Then run the driver script for the first real attempt, with the vendor tree absent only if the guards are first relaxed with the owner's approval for a "build-only, never-install" experiment (my recommendation is to wait for firmware instead).
4. **Kernel variant for Android 7:** apply the config fragment as an out-of-band kernel build (netfilter, UID routing question), choose the Samsung `SEC_RESTRICT` options deliberately, record vermagic for the modules.
5. **libGAL exception review** with the real library, together with the SELinux `execmod` grants.
6. **Wi-Fi module load order** (`mlan.ko` before `sd8xxx.ko`) and the Bluetooth path, once a kernel and firmware exist.
7. Keep camera and cellular out of scope until the above are solved.

## 10. Limitations

- No Android build ran. "Compiled" above means smoke tests of small sources and parsing of build files, nothing more.
- The cm-14.1 branch tips were fetched on 2026-11-05 and may have moved since the tag-based AOSP base was chosen; a real sync records exact revisions.
- The SELinux findings rest on reading sources and configuration; I did not run `checkpolicy`, and I did not run any kernel.
- Disk and host limits are specific to this sandbox; they say nothing about whether the project is feasible elsewhere.
