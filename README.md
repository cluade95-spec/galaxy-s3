# LineageOS 14.1 for Samsung GT-I8200 (goldenvess3g): feasibility project

Investigating whether Android 7.1.2 (LineageOS 14.1) can be brought to the Samsung Galaxy S III Mini Value Edition, **GT-I8200** (`goldenvess3g`, Marvell PXA986 board on the PXA988 kernel platform, Vivante GC1000).

Not to be confused with GT-I8200N / GT-I8200L (`goldenve3g`) or GT-I8190 (`golden`, a different chip). GT-I8200Q shares our codename.

## Status

| Phase | State |
|---|---|
| Milestone 1: feasibility report | Done: [docs/feasibility-report.md](docs/feasibility-report.md) |
| Phase 0: source verification | **Partly done:** [docs/phase-0-source-verification.md](docs/phase-0-source-verification.md) |
| Phase 1: study SM-T110 port | **Done (desk study):** [docs/phase-1-sm-t110-analysis.md](docs/phase-1-sm-t110-analysis.md) |
| Phase 2 preparation: authenticate kernel source and firmware | **Done as far as possible from here:** [docs/phase-2-preparation.md](docs/phase-2-preparation.md). No kernel work has started. |
| Phase 2: experimental kernel build (computer only) | **Done:** [docs/phase-2-kernel-build.md](docs/phase-2-kernel-build.md). Kernel and 20 modules built with the original toolchain. No kernel source changes. Nothing run on a phone. |
| Phase 3: device-tree feasibility (research) | **Done:** [docs/phase-3-device-tree-feasibility.md](docs/phase-3-device-tree-feasibility.md). Decision: enough evidence to start a staged, experimental device tree; **not** enough to promise a usable phone. |
| Phase 4: device-tree skeleton (computer only) | **Done:** [docs/phase-4-device-tree-skeleton.md](docs/phase-4-device-tree-skeleton.md), [docs/phase-4-cellular-investigation.md](docs/phase-4-cellular-investigation.md). Skeleton in `android/`. Not buildable yet, never built, nothing run on a phone. |
| Phase 5: vendor compatibility and cellular feasibility (computer only) | **Done:** [docs/phase-5-vendor-compatibility.md](docs/phase-5-vendor-compatibility.md), [docs/phase-5-cellular-feasibility.md](docs/phase-5-cellular-feasibility.md). Static analysis and source reading only. Nothing built into a ROM, nothing run on a phone. |
| Phase 6: first experimental build preparation and attempt | **Attempted, did not start:** [docs/phase-6-first-build-attempt.md](docs/phase-6-first-build-attempt.md). Stopped at the first gate (disk space), with further fundamental blockers found. Nothing built into a ROM, nothing run on a phone. |
| Phase 7: SELinux compatibility and build environment investigation (computer only) | **Done:** [docs/phase-7-selinux-compatibility.md](docs/phase-7-selinux-compatibility.md), [docs/phase-7-build-environment-and-firmware.md](docs/phase-7-build-environment-and-firmware.md). Back-port is feasible at compile level, not run. Nothing built into a ROM, nothing run on a phone. |
| Phase 8: SELinux back-port completion and runtime validation (computer only, QEMU) | **Done:** [docs/phase-8-selinux-runtime-validation.md](docs/phase-8-selinux-runtime-validation.md). Version 30 policy loads and extended permissions and all five binder hooks enforce in an emulator. Nothing built into a ROM, nothing run on the phone. |
| Phase 9: SELinux security review and kernel integration assessment (computer only, disposable copies) | **Done:** [docs/phase-9-final-recommendation.md](docs/phase-9-final-recommendation.md) (details: [patch review](docs/phase-9-selinux-patch-review.md), [binder fixes](docs/phase-9-binder-fixes.md), [audit](docs/phase-9-audit-investigation.md), [PXA988](docs/phase-9-pxa988-compatibility.md), [libGAL](docs/phase-9-libgal-alternatives.md)). Back-port: continue testing, not approved for production. Nothing built into a ROM, nothing run on the phone. |
| Phase 10+: official firmware and partition data, phone-board kernel with the patch, real build, hardware bring-up | Not started. Nothing has been tested on hardware. |

### Phase 0 key results
- **Best GT-I8200 kernel source found:** `Koloses/kernel_i8200` import commit `44afe4c` ("I8200XXUAOC1 kernel source"). Strong evidence it is Samsung's original package, built on a Samsung machine in Jan 2016. Not yet matched against Samsung's official download.
- **Gabrius99's goldenvess3g kernel is derived from the older GT-I8200N tree.** It won't be used as a base.
- **Firmware identity:** newest GT-I8200 build is I8200XXUAPB1 (Feb 2016). I8200XXUAOC1 (Mar 2015) matches the kernel source. All builds are Android 4.2.2. No firmware has been downloaded or checksummed yet.
- **NFC:** spec sheets say only the I8200N has NFC, but Samsung's kernel package was built with NFC enabled. Whether the phone has the chip is unconfirmed.
- **SM-T110 LineageOS 14.1 port:** the graphics compatibility patches look reusable. The project can't be rebuilt from its published files, and its hardware results are reported only by its owner.

### Phase 1 key results
- The SM-T110 project is a set of patches, not a reproducible ROM: at least 16 files its scripts need are unpublished, and its hardware results are the author's own report.
- Its kernel base is a postmarketOS fork (about 100 unexplained edits vs Samsung's SM-T110 source). The GT-I8200 plan is to start from the Koloses candidate and port single fixes.
- Graphics compatibility fixes look reusable: the GT-I8200 display-composer files use the same 100-byte layer record and extra composition types the patches target (static analysis of a community dump, not a test).
- The display kernel patch, camera HAL, installer and product files are tablet-specific and will not be copied.
- Telephony, camera and audio get no help from the SM-T110 project.

### Phase 2 preparation key results
- **Verdict: the Koloses kernel (`44afe4c`) is a plausible, consistent GT-I8200 source but is not authenticated.** Acceptable as a provisional reference; no kernel changes until it is checked against Samsung's official package or by compile-and-compare (needs your approval).
- A genuine Samsung GT-I8200 kernel image (March 2015, firmware I8200XXUAOC1) exists in a community device tree. Its build path says `GOLDENVESS3G` and its changelist number matches the firmware list. 98.4% of its symbol names are in the Koloses source and the rest are macro-generated.
- Which Samsung release the Koloses tree is, is unresolved. Its compile date (13 Jan 2016) fits I8200XXUAPB1 (17 Feb 2016), but the repo labels it OC1 and a GT-I8200N source is also possible.
- Target firmware: `GT-I8200`, PDA `I8200XXUAPB1`, changelist 2893589 (regions SER, SEE, BGL, VVT). The only route that proves origin is Samsung's own update server; mirrors are not accepted as proof. Nothing was downloaded.
- Stock kernel config cannot be read from firmware (not embedded). No device tree exists for this phone (board-file kernel, machine ID 3907, name "PXA988"). Partition sizes in community trees conflict and must not be used for anything that writes.

### Phase 2 kernel build key results
- **Built successfully** from `Koloses/kernel_i8200` @ `44afe4c` with the original Android 4.2 `arm-eabi-4.6` toolchain (GCC 4.6.x-google 20120106, from AOSP) and `pxa986_golden_rev02_defconfig`: `zImage` (3.9 MB, ARM, gzip) in about 80 seconds, plus 20 modules (GPU `galcore`, Wi-Fi, Bluetooth, modem interfaces). The original source was not modified; only 899 generated build leftovers were removed in a copy.
- **The compiled code matches a genuine Samsung GT-I8200 kernel.** With Samsung's production options on, all 5,144,576 code bytes are identical to the genuine March 2015 kernel image and all 41,847 symbols match in name, size and address. The whole image differs in 26 bytes after normalising the build-folder path (20-byte build fingerprint, 6 bytes of timestamps). It is **not** bit-identical as built, and I make no such claim.
- **The Koloses source is now a trustworthy base for experiments.** Still outstanding: comparison with Samsung's own download, and the newest firmware (I8200XXUAPB1). Nothing was run on a phone.
- **For a custom ROM:** Samsung's shipped kernel includes root/UID restrictions that are off in the plain defconfig; decide deliberately.
- Reproduce with `tools/kernel-build/build-golden-kernel.sh WORKDIR` (about 5 minutes).

### Phase 3 key results
- **Decision:** start a staged, computer-only device-tree skeleton. Result is uncertain: realistic worst case is Android 7.1.2 with Wi-Fi, Bluetooth and GPS but **no calls or mobile data**.
- **Existing trees:** Koloses `device_i8200` is the best starting material (phone-specific ramdisk files, genuine kernel); Gabrius99's tree is largely copied from a Galaxy Tab 3 tablet and is mostly unusable. Several leftovers from other devices (ST NFC, mdnie, reference-board camera tunings, `sd8777` firmware) must go.
- **Vendor dump audit (599 ARM ELF files):** all 32-bit ARM EABI5; 2 non-PIE executables Android 7 will refuse; 81 libraries with text relocations (including the GPU library); 13 required libraries missing from the proprietary list; `hwcomposer` and `power` HAL files omitted from the lists; `sensord` missing; dump is from a rooted phone.
- **Concrete Android 7 breaks found:** camera HAL needs 25 camera-parameter constants and removed vector symbols that Android 7 lacks, and `libstlport` (also needed by the Marvell RIL).
- **Good news:** audio HAL reports version 2.0 (Android 7's minimum) and the legacy audio-policy path still exists; Marvell RIL reports version 7 (Android 7 accepts 6 to 12); binder protocol 7 matches; LineageOS `hardware/marvell/wlan` and `/bt` exist for cm-14.1; GPS design matches the SM-T110 port.
- **Biggest blockers:** cellular stack (no precedent), missing official firmware/partition table, camera ABI gaps. GT-I8200 likely has no NFC.
- Correction: the `baffinlite` tree I earlier called a related Marvell design uses a Broadcom RIL.

### Phase 4 key results
- **Skeleton created** in `android/` (product/board makefiles, manifest pinning the Koloses kernel and toolchain, rootdir files, shim sources, guarded vendor-extraction tooling). It stops deliberately at TODOs: no boot offsets, partition sizes or hardware compatibility were invented.
- Koloses `device_i8200` audited file by file; tablet and reference-board leftovers (ST NFC, mdnie, `sd8777`, reference camera/touch files) dropped. The rooted community dump is not a source for the vendor tree; extraction only accepts verified official firmware.
- Component status: kernel provisional-ready; Wi-Fi, Bluetooth, audio, sensors, GPS, power incomplete; **camera, telephony, boot image and vendor tree blocked**; NFC unsupported.
- Vendor remediation plan R1-R8 (non-PIE, text relocations, missing libraries, libstlport, camera HAL, graphics shims, media, `sensord`).
- **Cellular:** the RIL's version 7 passes Android 7's 6-12 gate, but its request table ends at id 123 while Android 7 sends ids 124-132 at startup, so an interposer is likely needed. No Marvell-on-Android-5+ precedent exists. Plausible but unproven; the biggest project risk.

### Phase 5 key results
- **Recommendation: advance to a first experimental ROM *build* attempt, scoped to Wi-Fi, Bluetooth, GPS, graphics, audio playback and sensors. Camera and cellular are out of that first build. No flashing** until official firmware, the real partition table and a reversible, owner-approved procedure exist.
- **Text relocations:** 81 libraries in the community dump, 26 relevant to the manifest. Only `libGAL.so` (4,001 relocations in code) needs a linker exception for apps; the rest are loaded by platform processes and are covered by the board flag. With the flag, Android 7's SELinux policy allows device rules for `execmod`; that policy is not written yet.
- **Solved or narrowed:** echo-reference symbols are provided by Android 7's `libaudioutils`; sqlite and expat functions exist in Android 7 sources; `STUpdateTool` is an NFC flasher (excluded); `rtccd2` is a zram helper (replace with an fstab `zramsize=` entry); the sensors HAL does not link to `sensord` but dlopens `libacdapi_clb.so` (now in the manifest); `gs_modem` is a USB gadget name, not a missing telephony module.
- **New Wi-Fi finding:** Android 7 can load only one driver module through the HAL, but the Marvell driver is two modules (`mlan.ko`, `sd8xxx.ko`), so init must load the first. Bluetooth: the kernel driver's `/dev/mbtchar0` matches LineageOS's Marvell Bluetooth vendor library.
- **Cellular:** the vendor RIL has handlers for the basic GSM set (SIM, calls, SMS, registration, signal, data; 88 ids, list in `docs/data/ril-request-coverage.tsv`). Request ids 124 to 137 (the ones Android 7 adds) are outside its table and are **not** safe to forward and **not** safe to answer with success. An interposer prototype answers them with errors; a host test with a fake vendor library passes. Whether calls, SMS, data, SIM detection or registration work is unknown and cannot be tested without hardware and the modem firmware.
- **Camera** is the hardest vendor item (an unresolved `IMemoryHeap` destructor problem); it is deferred.

### Phase 6 key results
- **The build did not start.** The driver `tools/build/build-lineage.sh` stops at its preflight gates; first failure: 18 GiB free disk (a shallow sample of three projects is already 3.4 GiB of a 479-project tree). Also missing here: OpenJDK 8, python2, `repo`.
- **Inputs missing for any build:** official firmware (so zero vendor files), verified boot image values and partition sizes, and a kernel built with SELinux. `build-guards.mk` now makes the build refuse to run without them instead of falling back to tool defaults.
- **SELinux is a fundamental blocker (corrects Phase 4 wording).** The kernel has no SELinux, and Android 7's init cannot start without it. The kernel's SELinux only understands policy version 26 and has no ioctl extended-permission code, while Android 7.1.2's policy is version 30 and uses it. Options (kernel back-port, policy changes, or running without SELinux) are listed in the Phase 6 document; none is applied. The SM-T110 reference port runs with SELinux disabled.
- **libGAL:** an opt-in, single-path linker exception is written as a proposal (`patches/bionic-libGAL-textrel.patch`, applies cleanly to cm-14.1 bionic, not applied) pending your decision and the SELinux outcome.
- **Fixes made:** kernel provided out of band (the Koloses tree cannot be built through Lineage's kernel.mk without modifying the kernel source), pinned toolchain wired, build guards, manifest and interposer corrections. Pinned revisions verified (4 of 4).
- **What compiled:** only smoke tests (shim sources with the pinned old GCC, interposer syntax with clang, the real cm-14.1 product/board configuration resolving for `lineage_goldenvess3g`). No ROM, no boot, no hardware claim.
- **Not safe for controlled testing yet.** Phase 7: decide SELinux, obtain official firmware and the partition table, find a supported build host.

### Phase 7 key results
- **SELinux back-port is technically feasible, but unproven at run time.** Google published the needed code for Linux 3.4 (`kernel/common`, `deprecated/android-3.4`): policy formats 27 to 30 and ioctl extended permissions. Applied to a *separate copy* of our kernel (the pinned clone was never touched) it compiles with SELinux on: about 26 files, +1,366 / -139 lines, all under `security/` plus two headers. Still missing: five binder hook calls, and any run-time test (no kernel was run).
- **Android 7.1.2's policy compiles at version 30 with no errors; at 26 to 29 it fails with exactly one error class** (5 `allowxperm` rules need version 30). Deleting those rules would *widen* access (they narrow `ioctl`), so no security-preserving version-26 policy exists; I did not strip anything. The kernel must be extended instead.
- **libGAL exception:** conditionally acceptable for an experimental, non-daily-use build only. The linker change is one exact path; the cost is an SELinux `execmod` grant (new for `surfaceflinger`, `mediaserver`, `bootanim`; small extra for apps, which already have `execmem`). Best scoping needs one reviewed `neverallow` exemption for a dedicated file type, otherwise the grant covers all of `/system`. Not applied. The text-relocation board flag is now marked as a pending owner decision.
- **Build environment:** Ubuntu 16.04 userland (OpenJDK 8, Python 2.7, make 4.1) in a chroot on the Ubuntu 24.04 host, with `repo` run on the host. Test in a scratch folder: tarball hash verified, Python, OpenJDK 8 and make run; host untouched. Ubuntu 24.04 has no `python2`.
- **Disk:** all 479 projects resolve (586,344 files; 488,354 in the default groups). Measured shallow samples (14 projects, 42 % of files) = 13.3 GiB. Estimate: 75 to 175 GiB in use; **reserve at least 200 GiB free, 250 GiB recommended**.
- **Still needed from Samsung (nothing may be substituted):** official kernel source package, official firmware for GT-I8200 with hashes, the boot image header, and the partition table (PIT or read-only phone output). Exact list in Part D.
- **Recommendation: GO for computer-only preparation in Phase 8** (binder hooks in a copy, emulator test of policy loading, build environment). **NO-GO for hardware tests, flashing, or a full ROM build** until firmware and partition data exist, the back-port has loaded the version-30 policy under emulation, and you have decided the SELinux and libGAL questions.

### Phase 8 key results
- **The five missing binder LSM hook calls were ported** (same sites as Google's android-3.4) and the whole SELinux back-port is now one patch, `tools/selinux/patches/android-3.4-selinux-backport.patch` (27 files, +1,387 / -139). It was **not applied** to the pinned kernel clone, which was never modified.
- **QEMU runtime test** (ARM Versatile Express, Linux 3.4.5 built from our Samsung tree; QEMU unpacked from hash-checked Ubuntu packages, nothing installed): the unmodified Android 7.1.2 policy (version 30) **is refused** by the pinned source (`policydb version 30 does not match my version range 15-26`) and **loads** with the back-port (`policyvers` 30).
- **Extended permissions are enforced** with the real Android rules in enforcing mode: `untrusted_app` is denied `SIOCGIFHWADDR` and `SIOCGIFMETRIC` and allowed the unprivileged ioctls; `priv_app` gets `SIOCGIFHWADDR` through its own rule; a control domain with no `allowxperm` rule is allowed everything; permissive mode allows everything.
- **All five binder hooks enforce, individually**: each denial case is denied with the hooks and allowed without them (14 of 19 cases pass when the hooks-less kernel is judged against the hooks expectation: exactly the five denial cases fail).
- **Not proven:** anything on the phone's hardware, real Android userspace, ext4 labels, long-run behaviour. A first run gave meaningless all-zero results (a harness bug: `wait4` was being denied); it was found and fixed before any result was used.
- **libGAL dedicated file type reviewed, not applied.** It needs one exemption in the platform's `domain.te` (4 lines) plus guard assertions; with them the policy compiles with the broad text-relocation flag **off** (now switched off in `BoardConfig.mk`), and at run time `execmod` is confined to that one file type. It remains a real weakening (a code-injection primitive limited to that library's pages for services that have no `execmod` or `execmem` today) and needs your decision. With the flag off the linker refuses every other text-relocation library.
- **Build environment:** `tools/build/xenial-userland.sh` (fetch with hash check, extract, install, enter, teardown); fetch, enter and teardown were tested; the `apt` install step was not (sandbox limits).
- **Still required before a full build:** official firmware and partition data, your decisions (adopt the kernel patch series, libGAL design), a phone-board kernel built from source plus the patch, and a build host.

### Phase 9 key results
- **SELinux back-port: continue testing, not approved for production.** No Critical finding; it matches Google's android-3.4 code. High finding: 13 later SELinux security fixes are missing (they apply and compile; patches in `tools/selinux/patches/proposed/selinux-followups/`, 7 more do not apply).
- **Binder:** the unmodified Samsung binder has a use-after-free on thread exit with epoll (reproduced in QEMU with poison checking; fixed by proposed patch PB2). PB2 is required; PB4 recommended; PB1 and PB3 optional. Nothing was applied to the pinned kernel.
- **Missing audit records explained:** the kernel's printk rate limit dropped them (10 of 14 denials seen by default, 14 of 14 with the limit off or an audit-netlink listener). Enforcement was never affected.
- **Real board config compiles** with the patch (zImage and 20 modules, with and without Samsung ship options). The shipped defconfig has no SELinux or audit at all, so those must be enabled. Compile only; no boot.
- **libGAL:** cannot be rebuilt (no sources) or realistically binary-patched (4,001 text relocation sites). A narrow exception looks unavoidable for GPU acceleration; Mesa software rendering is an untested alternative. Decision: unresolved.
- **Full ROM build: NO-GO.** All Phase 9 test results are static or emulator results, not hardware validation.

### Open blockers
- `opensource.samsung.com` and Samsung firmware servers are blocked by this environment's network policy (re-tested 2026-11-05). That blocks the official kernel package and stock firmware checksums. Allow them in Environment settings → Network access, or supply the files and hashes yourself (see the Phase 2 document).
- Phone identity details are needed from the owner (model, baseband, build number, NFC toggle). Look only, change nothing.

**Safety rules:** nothing is flashed or written to the physical phone. Unverified ROMs are not downloaded. No feature is claimed to work without evidence.
