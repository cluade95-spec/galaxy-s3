# Phase 4: GT-I8200 (goldenvess3g) device-tree skeleton

Computer-only. Nothing was built into a ROM, nothing was run on a phone, and no firmware or proprietary file was downloaded or committed. The skeleton **cannot build yet** (it stops deliberately at TODOs) and **must not be flashed**.

Inputs: kernel `Koloses/kernel_i8200` @ `44afe4cf6023bf39c18bad72185003a40915fad2` (Phase 2/3), target LineageOS 14.1 (Android 7.1.2). Cellular has its own document: [phase-4-cellular-investigation.md](phase-4-cellular-investigation.md).

Labels used in the files: **VERIFIED** (checked against kernel/binaries/source), **DERIVED** (inferred from verified evidence), **CLAIMED** (from a community file, unchecked), **DECISION** (my choice, reversible), **TODO** (unknown, deliberately left blank).

## 1. What was created (`android/`)

| Path | Contents |
|---|---|
| `device/samsung/goldenvess3g/` | `AndroidProducts.mk`, `lineage_goldenvess3g.mk`, `device.mk`, `BoardConfig.mk`, `system.prop` (comment only) |
| `.../local_manifest.xml`, `lineage.dependencies` | Pins kernel (`44afe4cf…`), AOSP `arm-eabi-4.6` (`d73a051b…`), LineageOS `hardware/marvell/wlan` and `bt` (cm-14.1, pinned commits) |
| `.../kernel/` | Integration questions and an **unapplied** Android 7 config fragment (netfilter/conntrack/idletimer, UID routing note, SELinux decision) |
| `.../rootdir/etc/` | `fstab.pxa988` (CLAIMED by-name entries, no sizes), `ueventd.pxa988.rc`, `init.pxa988.rc` (Android 7 syntax), `init.pxa988.tel.rc` (empty stub, BLOCKED) |
| `.../configs/audio_policy.conf` | Koloses stock file plus a TODO about the Android 7 parser |
| `.../shims/` | `libshim_goldenvess3g` sources (VectorImpl reserved symbols, RefBase::moveReferences, binder getCallingPid forwarder) and the 25 camera-constant names. Host syntax-checked only; **unbuilt, untested** |
| `.../sepolicy/`, `overlay/` | Empty with README (TODO) |
| `vendor/samsung/goldenvess3g/` | `proprietary-files.txt` (200 active entries, flagged), guarded `extract-files.sh`, `generate-vendor-mk.py`, README. **No blobs.** `/proprietary/` and generated makefiles are git-ignored |
| `tools/vendor/` | `gen-camera-shim.py` (reads constants from an official `libcamera_client.so`), `elf-audit.py` |

BoardConfig deliberately leaves boot image offsets, base, page size and every partition size as commented TODOs (the mkbootimg defaults are tool defaults, not evidence). `TARGET_OTA_ASSERT_DEVICE` is `goldenvess3g`, which does not separate GT-I8200 from GT-I8200Q (TODO). Debug defaults (`ro.secure=0`, `ro.debuggable=1`) were not carried over.

## 2. Audit of `Koloses/device_i8200` (@ `3bcf4bb`)

| Item | Decision | Reason |
|---|---|---|
| Ramdisk `fstab.pxa988` | **Used, rewritten** | Phone-specific; partition numbers CLAIMED; no sizes; preload/encryption left TODO |
| Ramdisk `ueventd.pxa988.rc` | **Used, subset** | Kept GPU, framebuffer, camera, audio, sensors, GPS UART, Wi-Fi/BT, touch; dropped raw partition-number rules, tablet and reference-board nodes |
| Ramdisk `init.pxa988.rc` | **Used, rewritten** | Kept galcore/geu insmod parameters, permissions, interface props. Dropped the ST NFC property (`ro.stollmann.nfc`): no ST chip on this board |
| Telephony rc (`tel_launch`, daemons) | **Documented only** | Stock services listed as comments; not enabled (BLOCKED) |
| `audio_policy.conf` | **Used** with TODO | Parser behaviour on N unverified |
| `ro.cm.hardware.cabc` mdnie path | **Dropped** | AMOLED panel, no mdnie support in the kernel |
| Camera tunings `ov5647/ov8825/lsi3h5`, touch maps `elan/ft5306` | **Dropped** | Reference-board hardware; this phone has S5K4ECGX/SR030PC30, Atmel mXT224S |
| `sd8777` Wi-Fi firmware | **Dropped** | Tablet's; phone files are `sd8787` |
| Placeholder partition sizes, `twrp.fstab` | **Not used** | Placeholders; `twrp.fstab` gives p16 to both `/data` and `/preload` |
| Gabrius99 tree | **Not used** | Largely copied from Galaxy Tab 3 (SM-T211) |
| Prebuilt kernel image | **Not used** | Kernel comes from source |

NFC: no NFC HAL or permission in the GT-I8200 dump, so none is configured (the I8200N has it).

## 3. Component status

| Component | Status | Notes |
|---|---|---|
| Kernel source / config | **Ready (provisional)** | Builds; code matches genuine Samsung image. Not compared to Samsung's own download |
| Kernel integration into Lineage build | **Incomplete** | Android 7 options not applied (would need kernel-tree edit); toolchain wiring, host perl issue, Samsung root restrictions undecided |
| Boot image params | **Blocked** | No verified offsets or sizes |
| Partition layout / fstab | **Incomplete** | Numbers CLAIMED, sizes unknown (no safe source) |
| Product makefiles | **Ready (structure)** | Density TODO (~234 dpi derived, unverified) |
| GPU / display | **Incomplete** | galcore parameters from stock; needs text-reloc exception for libGAL, graphics shims, HWC checks; all untested |
| Wi-Fi (88W8787) | **Incomplete** | LineageOS marvell_wlan pinned; firmware and driver glue untested |
| Bluetooth | **Incomplete** | marvell_bt pinned; untested |
| Audio | **Incomplete** | HAL reports 2.0 (N minimum); legacy policy path exists; untested |
| Camera | **Blocked** | HAL1 blob needs removed symbols, libstlport, IMemoryHeap handling (no design) |
| Sensors | **Incomplete** | MPU6500 HAL present, `sensord` not in dump |
| GPS | **Incomplete** | UART2 design matches SM-T110 port; untested |
| Power / lights | **Incomplete** | HALs omitted from community lists; included in manifest, untested |
| Telephony / mobile data | **Blocked** | See cellular document |
| NFC | **Unsupported** | Not present on this model (DERIVED) |
| SELinux policy | **Incomplete** | Not written; permissive vs enforcing undecided |
| Vendor tree | **Blocked** | Needs verified official firmware; tooling ready, never run on real firmware |
| Recovery | **Not started** | Out of scope |

## 4. Vendor compatibility remediation plan

Based on the Phase 3 audit of a rooted, unverified-origin community dump (599 ARM ELF files). Facts below are name-level static checks; changed signatures and layouts are not detectable this way.

| ID | Problem | Plan | Status |
|---|---|---|---|
| R1 | 2 non-PIE executables (`bin/rtccd2`, `bin/STUpdateTool_V4_4R`); N's linker aborts them | Defer both (not needed for boot; marked `#DEFER`); allow-list header (`LINKER_NON_PIE_EXECUTABLES_HEADER_DIR`) only if one proves necessary | Planned |
| R2 | 81 libs with text relocations (incl. GPU lib); rejected for target SDK > 22 | `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS := true` (set) plus a bionic exception for libGAL ported from the SM-T110 patch (not yet ported). Workaround, not a fix | Partly done |
| R3 | 13 required libs absent from community lists; `hwcomposer.mrvl`, `power.mrvl` omitted | Added to `proprietary-files.txt` with flags; to be checked against official firmware | Listed |
| R4 | `libstlport` removed from N (needed by camera HAL and RIL) | Ship the stock library from official firmware as a blob; no shim | Waiting for firmware |
| R5 | Camera HAL: 25 CameraParameters constants, VectorImpl/SortedVectorImpl reserved1-8, RefBase::moveReferences, IMemoryHeap D0/D1/D2 + thunks | Generator emits the 25 constants from official `libcamera_client.so`; VectorImpl/RefBase shims written; IMemoryHeap destructors need a design (deliberately not faked); stock `libcamera_client` behaviour to be checked | Partly written, unbuilt |
| R6 | Graphics: `IPCThreadState::getCallingPid` symbol form, HWC 100-byte layer record and extra composition types | Forwarder shim written (needs LD_PRELOAD/shim wiring); HWC and SM-T110 retire/queue patches to be re-verified against this phone's `hwcomposer` | Partly written |
| R7 | Stagefright extractors / OMX codecs | Deferred; media not required for first boot | Deferred |
| R8 | `sensord` missing from the dump | Look for it in official firmware; test the sensors HAL without it | Open |

### Extraction gating
`extract-files.sh` refuses to run unless `GOLDEN_FW_DIR` holds a `system/` tree and a `PROVENANCE.txt` (source, package name, size, sha256, origin = samsung-fus or samsung-opensource). It rejects forbidden model names (I8200N/L/Q, I8190), wrong `build.prop` model/device/fingerprint, root artifacts (su, SuperSU, install-recovery) and path escapes. Refusal paths were tested with synthetic data in scratch space (7 refusal cases; one clean synthetic tree copied 2 files and reported 198 missing). It has never been run on real firmware.

## 5. Limitations

- No ROM build, no kernel build in this phase, no phone contact. The skeleton was only syntax-checked (XML/JSON validity, shim sources with host g++ `-fsyntax-only`).
- Official firmware and Samsung's official kernel package remain unobtained (network policy blocks Samsung hosts); no partition sizes exist.
- Every blob finding comes from a community dump and may differ from official firmware.
- Nothing is claimed to work.

## 6. Next steps (each needs the user's say-so where noted)

1. Obtain official GT-I8200 firmware and its hash (needs network access or user-supplied files) → run extraction, re-audit.
2. Phone identity details from the owner (read-only look).
3. Decide Samsung root-restriction and SELinux policy for the kernel.
4. Only after a successful computer-only Lineage build attempt: discuss any hardware testing (requires explicit approval).
