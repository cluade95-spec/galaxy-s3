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
| Phases 3–5: recovery/ROM build, hardware bring-up | Not started. Nothing has been tested on hardware. |

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

### Open blockers
- `opensource.samsung.com` and Samsung firmware servers are blocked by this environment's network policy (re-tested 2026-11-05). That blocks the official kernel package and stock firmware checksums. Allow them in Environment settings → Network access, or supply the files and hashes yourself (see the Phase 2 document).
- Phone identity details are needed from the owner (model, baseband, build number, NFC toggle). Look only, change nothing.

**Safety rules:** nothing is flashed or written to the physical phone. Unverified ROMs are not downloaded. No feature is claimed to work without evidence.
