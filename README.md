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
| Phase 6+: first experimental ROM build, recovery, hardware bring-up | Not started. Nothing has been tested on hardware. |

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

### Open blockers
- `opensource.samsung.com` and Samsung firmware servers are blocked by this environment's network policy (re-tested 2026-11-05). That blocks the official kernel package and stock firmware checksums. Allow them in Environment settings → Network access, or supply the files and hashes yourself (see the Phase 2 document).
- Phone identity details are needed from the owner (model, baseband, build number, NFC toggle). Look only, change nothing.

**Safety rules:** nothing is flashed or written to the physical phone. Unverified ROMs are not downloaded. No feature is claimed to work without evidence.
