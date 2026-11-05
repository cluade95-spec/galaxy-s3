# Phase 1: SM-T110 LineageOS 14.1 project analysis

**Date:** 2026-11-05 · **Scope:** what in the SM-T110 (`goyawifi`) Android 7.1.2 port could help the GT-I8200 (`goldenvess3g`), what would need changing, and what must not be copied.
**Rules followed:** nothing compiled, flashed or written to any phone. No ROM or firmware image was downloaded. The only "execution" was `git apply --check` (a dry run that edits nothing) and read-only disassembly of files already in public repositories.

## How to read this document

| Label | Meaning |
|---|---|
| **VERIFIED** | I checked it directly in files or git data. Anyone can repeat it with the IDs given. |
| **STATIC** | Read from disassembly or file structure of a binary. Reliable for what it shows, but the binary was never run, and its origin is a community dump (see 3.4). |
| **CLAIMED** | Stated by the SM-T110 project's author. Nothing published lets me check it. |
| **UNKNOWN** | Not established. |

---

## 1. Summary in plain language

1. **The SM-T110 project is a set of patches plus notes. It is not a reproducible ROM.** The repository has no vendor files, no complete source list, and no build inputs for the final system image. At least 16 files its scripts need are absent (section 6). Its hardware results are the author's own word and no logs are published.
2. **Its kernel base is not Samsung's SM-T110 kernel.** It is a postmarketOS (a Linux-for-phones project) fork with about 100 edits that the Android port neither lists nor explains. I won't use it as a base for the GT-I8200. I'll start from the Koloses GT-I8200 candidate and port individual fixes.
3. **The graphics compatibility fixes look genuinely reusable.** The hardest part of the port is making Android 7's display code talk to the old Android 4.2 Marvell graphics files. I disassembled the GT-I8200 copies of those files and found the same quirks the SM-T110 patches work around:
   - The GT-I8200 display composer uses a **100-byte** per-layer record, the same figure the SM-T110 patch hard-codes.
   - It uses the same two extra composition types (100 and 101).
   - The graphics library needs the same text-relocation exemption.
   - The graphics buffer module imports the same binder function the SM-T110 shim re-exports.

   This is static evidence on a community copy of the files, not a test on a phone.
4. **The display kernel patch cannot be used.** The SM-T110 has a different screen controller. The GT-I8200 is built with a Samsung S6E63M0 480×800 panel driver, and the code the patch edits is not even compiled for the GT-I8200 board.
5. **The camera, sensor, boot-loader, installer and product files are tablet-specific.** The camera driver is written for one specific sensor with fixed resolutions, the installer is hard-wired to the tablet's partition numbers, and the product files make the device a Wi-Fi-only tablet with no phone stack. None of these can be copied.
6. **Four kernel patches dry-run cleanly against the Koloses kernel** (text-level only). That is not a build and not a test.
7. **The SM-T110 build ships with SELinux off** (its own README says so). Its bring-up init patch also replaces Android's property-permission check with "root or system only". Whether the shipped image uses that init build is not published. For a phone I'd want a better answer.

**Bottom line:** Phase 1 narrows the work. 9 of the 12 patches contain something reusable or adaptable (several only with changes) and 3 are not usable. Everything else is reference reading. The graphics work is probably tractable. Telephony, camera and audio still have to be built from the GT-I8200's own files, and Phase 1 found nothing that helps with telephony.

---

## 2. What was examined

### 2.1 The repository (VERIFIED)

| Item | Value |
|---|---|
| URL | https://github.com/jakaco/lineageos-14.1-goyawifi |
| Commit audited | `df7ed54649066b0304b324359d3631037e6664c1` (tree `cd2fae8c6d585156a7c01d25b1a54f6ec33d7090`) |
| Tags | `lineage-14.1-goyawifi-2026.11.04-r1` → `26e600aed6c5939e761bdebf789145b30d19abfa`; `…-r2` → `df7ed546…` |
| History | 6 commits, all on 2026-11-04 between 15:37 and 16:39 (+0100). There is no history before that afternoon. |
| Files | 59 files, listed in the checksum table in Appendix A |
| Release ZIPs | Not downloaded (your rule). GitHub's release pages returned HTTP 403 through this environment's proxy, so their existence and size are unchecked. The repo lists their hashes: r1 `bbb5be4a…10ff`, r2 `df213221…cfdf`. |

Every file was read in full: 8 Android patches, 4 kernel patches, 9 build/packaging scripts, 3 device directories, the init script, both manifests, both pin files, the kernel config and the TWRP installer.

### 2.2 The comparison targets

| Name | What | Commit |
|---|---|---|
| **KOL** | GT-I8200 kernel candidate (Koloses import) | `44afe4cf6023bf39c18bad72185003a40915fad2` (tree `0eebf6f9…`) |
| **T110K** | Kernel the SM-T110 port uses (`T110-pmOS/linux_kernel_pxa988`) | `fb2f8b6cd86864c0fcac790e97a372b1772003c7` (tree `fa0eb07d…`) |
| **GOYA** | Samsung's own SM-T110 kernel (`T110-android/samsung_kernel_goya`) | `562ba82bb07bde98d1876eb1f8fec8de019cb301` |
| GT-I8200 files dump | `Gabrius99/proprietary_vendor_samsung_goldenvess3g` | `61139fc67f9184c154926175fdee933fa40b2712` |

---

## 3. Findings by area

### 3.1 The SM-T110 kernel base (VERIFIED)

- The port's kernel pointer (`sources/kernel-source.json`) is T110K, a postmarketOS project from 2021–2022 by "cheadrian" (5 commits). The jakaco port adds four patches on top.
- **T110K differs from Samsung's SM-T110 source (GOYA) in 103 files, has 270 files GOYA lacks, and lacks 22 that GOYA has.** The differences include:
  - Open-source GPU (Etnaviv) and graphics-memory (CMA) backports, which the Android port's config keeps (`CONFIG_CMA_SIZE_MBYTES=128`).
  - Eight edits inside Samsung's GPU kernel driver (`galcore`), for example removing a memory-mapping branch (`mdl->bPmem`) and some tracing.
  - Edits to the Wi-Fi/Bluetooth driver (`mbt_char.c` rewritten to a different character-device API), the USB gadget code, the touchscreen driver and the `goya` board file.
  - A different watchdog reset flag and removal of a Wi-Fi LDO voltage setting in `board-goya.c`.
- None of this is documented in the Android port. So the port's real kernel is "Samsung source plus an unreviewed pmOS delta plus four patches".
- The Android port's kernel command line is baked into the config (`sources/kernel.config`): `selinux=0 androidboot.selinux=disabled enforcing=0 goyawifi.initrd_size=1419841 goyawifi.lcd_init=1`. The `1419841` is the byte size of one specific ramdisk and cannot be reused.

### 3.2 SM-T110 kernel vs. the GT-I8200 candidate (KOL), file by file (VERIFIED)

Method: git blob fingerprints for every file in both trees.

| Comparison | Identical | Different | Only in T110K | Only in KOL |
|---|---|---|---|---|
| T110K vs KOL | 39,883 | **165** | 173 | 946 |

The 165 differing files: 19 in the GPU driver, 15 in `arch/arm/mach-mmp` (board files), 11 documentation, 8 in `mm`, 6 in `kernel`, 5 in `drivers/gpu/drm`, plus small groups in USB gadget, camera drivers, touchscreen, Wi-Fi/Bluetooth, telephony and networking. Most "only in KOL" files are other Samsung boards' configs and generated build files. Most "only in T110K" files are the Etnaviv driver and its supporting backports.

**Board and display (VERIFIED):**

| | GT-I8200 (KOL, `CONFIG_MACH_GOLDEN`) | SM-T110 (`CONFIG_MACH_GOYA`) |
|---|---|---|
| Panel code compiled in | `board-golden-display.o lcd_s6e63m0.o lcd_s6e63m0_smart.o` (Samsung S6E63M0, 480×800, 52×86 mm) | `board-goya-display.o Lcd_mipi2lvds_vx5b3d.o` (a MIPI-to-LVDS bridge for a tablet screen) |
| Source | `arch/arm/mach-mmp/onboard/Makefile` lines 20 and 21 | same file |
| Touch/sensors/camera in kernel config | `TOUCHSCREEN_MXT224S`, MPU6500 motion sensor, ALPS compass, GP2A proximity, `SOC_CAMERA_S5K4ECGX`, NFC (PN547) | `TOUCHSCREEN_BT532_TS`, BMA25x accelerometer, `SOC_CAMERA_SR200PC20M`, no NFC |

(Camera and touch controller names above come from each config's enabled options. The golden board file also contains options for other sensors and a touch controller variant, so the exact parts fitted to a GT-I8200 are still **UNKNOWN** until read from the phone or the firmware.)

**The GPU kernel driver is not the same code in the two kernels (VERIFIED), even though both say version 4.6.9 build 4651.**
- 19 of its files differ. The biggest difference is `gc_hal_kernel_hardware.c` (about 490 changed lines).
- KOL has changes T110K lacks: a clock-gating atom (`IsrClkoff`) and a tile-status flush in the command stream.
- 14 of the 19 differing files are byte-identical to Samsung's SM-T110 source (GOYA). So KOL is not "older" or "newer" than the SM-T110 driver in a simple way. It is a different Samsung drop with the same version number.
- **GT-I8200 user-space graphics library `libGAL.so` carries the string `$VERSION$4.6.9:4651$`** (STATIC), matching the kernel driver's declared version.
- **Consequence:** keep the GT-I8200 kernel GPU driver and the GT-I8200 firmware's graphics files together as one matched set. Never mix the SM-T110's GPU driver or files into a GT-I8200 build.

**The frame-buffer driver `drivers/video/pxa168fb.c` is byte-identical in KOL and T110K** (VERIFIED). Its vsync wait handler (`FB_IOCTL_WAIT_VSYNC`) exists in both. I did not confirm the numeric ioctl value that the SM-T110 "retire thread" patch calls (`_IO('m',18)`), because the header defining it was not found in the files I could read cheaply.

### 3.3 Kernel config differences that matter (VERIFIED, from the two config files)

Compared `pxa986_golden_rev02_defconfig` (KOL) with the port's `sources/kernel.config`: 2,352 options appear in both, 48 of them with different values, 29 appear only in KOL's config and 60 only in the port's. The relevant ones:

| Area | KOL golden config | SM-T110 port config | Meaning for GT-I8200 |
|---|---|---|---|
| SELinux / audit | `SECURITY` off, `AUDIT` off | on (SELinux built in, but run with `selinux=0`) | Android 7.1 expects a policy-loading kernel. We need to decide: build SELinux in and run permissive, or copy the port's disable-SELinux hack (not recommended). |
| Netfilter mark/connmark/conntrack | `XT_MARK`, `XT_CONNMARK`, `MATCH_MARK`, `MATCH_CONNMARK`, `MATCH_CONNTRACK`, `TARGET_MARK`, `TARGET_CONNMARK`, `TARGET_IDLETIMER` all **off** | all `=m` (modules) | Android 7 networking uses these. They are candidates to enable (to be checked against Android 7.1's published kernel requirements, which I have not yet done). |
| Qtaguid, IP policy routing, paranoid network, ashmem, binder, ION, LMK | already on | already on | Good: no change needed. |
| `NETFILTER_XT_MATCH_OWNER` | off | off | Off in both. Whether Android 7.1 netd needs it is **UNKNOWN**. |
| `EXT4_FS_SECURITY`, `TMPFS_XATTR` | off / on | on / on | The port turns on ext4 security labels. |
| `CMDLINE` | `initrd=0x01100000,1m … console=ttyS1` from bootloader | hard-coded, includes the tablet ramdisk size | Do not copy. |
| Cgroups, cpusets | off in both | off in both | Unchanged (no evidence they are needed for boot). |
| NFC (PN547) | on | off | GT-I8200 has the NFC driver compiled in the Samsung config (see Phase 0). |

### 3.4 Graphics and display files in the GT-I8200 dump: do the SM-T110 patches' assumptions hold? (STATIC)

Caveat: the files come from the Gabrius99 dump (a rooted, unverified-origin copy of a GT-I8200 `/system`). The graphics libraries below are byte-identical to the ones in the GT-I8200N dump (Phase 0). I read their structure and disassembled them with `capstone`; nothing was executed. The helper is `tools/disasm_symbol.py`.

| Assumption in the SM-T110 patches | What the GT-I8200 files show | Result |
|---|---|---|
| Stock display composer (HWC) uses a **100-byte** layer stride and the layer list starts at offset **20** (`static_assert(sizeof(hwc_layer_1_t)==100)`, `hwLayers==20`) | In `libHWComposerGC.so`, `hwc_prepare_gc` loads `movs r2,#0x64` (100) and indexes layers with `mla lr, r2, r8, r4` (list pointer + 100×index), then stores through `[lr,#0x14]` (offset 20). Layer count is read from `[list,#0x10]`. | **Matches** |
| Extra composition types 100 and 101 ("HWC_G2D") | `hwc_prepare_gc` stores `0x65` (101) into the composition-type field of eligible layers and tests `cmp r1,#0x63 ; strgt` (anything above 99 is reset to a framebuffer layer). The library also exports `hwcComposeG2D`. | **Matches** (101 seen; 100 not separately confirmed) |
| Layer field offsets: flags at 8, handle at 12 | Disassembly reads `[layer,#8]` and tests bit 0 (the skip-layer flag), and reads `[layer,#0xc]` | **Matches** for those two fields |
| Global alpha stored as an extra 32-bit word at offset 24; crop at 28; frame at 44; and so on (the `static_assert` offsets) | Not traced | **UNKNOWN**: needs more disassembly or a runtime test |
| Device reports HWC version 1.2 | The `hwcomposer.mrvl.so` wrapper contains the constant `0x01020001` (HWC 1.2). `libHWComposerGC.so` also contains `0x01010001` (1.1). | **Consistent with 1.2**, not conclusive |
| `libGAL.so` has text relocations (the bionic linker exemption exists for it) | `readelf -d`: `TEXTREL` present, flags `SYMBOLIC TEXTREL BIND_NOW` | **Matches** |
| Stock `gralloc` imports the non-const `IPCThreadState::getCallingPid` (the binder shim exists for it) | `nm -D --undefined-only gralloc.mrvl.so` lists `_ZN7android14IPCThreadState13getCallingPidEv` (non-const) | **Matches** |
| Stock graphics stack is the Vivante/Marvell chain | `hwcomposer.mrvl.so` → `libHWComposerGC.so` + `libEGL.so`; `gralloc.mrvl.so` → `libGAL.so`, `libgcu.so`; `libEGL_MRVL.so`, `libGLESv2_MRVL.so` → `libGAL.so` | **Matches** |
| EGL queues buffers on a worker after `eglSwapBuffers` returns (the "legacy EGL queue" workaround) | Behaviour, not structure. Needs a runtime test. | **UNKNOWN** |
| Display-vsync retire fence missing (the "retire thread" workaround) | HWC returns no fence by its structure, but I can't prove that statically | **UNKNOWN** |
| Display density reported in integer DPI (the "×1000" fix) | Not traced | **UNKNOWN** (panel-dependent anyway) |

**Not found:** none of the graphics user-space code is available as source. Samsung's published SM-T110 platform source (`T110-android/samsung_platform_goya`, commit `41ff63eadd36a9c493b9fce07b682d2c41187cb4`, 41,252 files) contains only open-source components under `external/`, `vendor/marvell/external/alsa-lib`, `vendor/marvell/generic/PowerDaemon`, `vendor/marvell/external/cpufrequtils` and `vendor/samsung/common/`. It has no gralloc, HWC, EGL, GPU or camera source. So every graphics fix has to work around closed binaries.

### 3.5 What the SM-T110 camera, audio and sensor work actually is

- **Camera (VERIFIED from source):** `goyawifi-camera/camera-hal.cpp` is a hand-written HAL1 camera that opens `/dev/video0` with V4L2 user-pointer buffers and ION memory. It supports only 640×480 and 320×240 preview and 1600×1200 or 640×480 pictures, with zoom and focus areas switched off in its parameter list. Its own dump string says "rear SR200PC20M". It sets sensor registers through `VIDIOC_DBG_S_REGISTER` with magic control numbers (`V4L2_CID_BASE+68/69/49`). This is a minimal one-sensor bring-up. "Camera works" in the SM-T110 status therefore means a basic low-resolution preview and photo path.
- **Audio (VERIFIED from the repo's own text):** the init script says "Source-built generic stub audio for framework boot; Marvell audio is unported". Yet the README reports audio working. The audio that works is inside the unpublished `audio-runtime` overlay folder, so how it works cannot be examined.
- **Sensors:** the accelerometer fix is a boot script that changes permissions on `/sys/class/input/input4/…`. That input number is specific to the tablet's device order and the BMA25x sensor. The GT-I8200 has an MPU6500 motion sensor plus compass and proximity chips. Not reusable.

### 3.6 Claims vs. evidence

| Claim in the SM-T110 repo | Evidence available | Assessment |
|---|---|---|
| Boot, UI, Wi-Fi, audio, Bluetooth, camera, video decode, GPS, rotation work | One owner's report; "owner-visible" evidence; GPS "no coordinate log" | **CLAIMED**, unverifiable |
| Updater "checks … recovery fingerprint" (`README.md` line 7; `packaging/twrp/README.md` line 3) | `update-binary` contains no fingerprint check (grep count 0). It checks model, device, partition links, partition sizes and payload hashes. | **Contradicted by its own installer** |
| Build is `user` variant with secure ADB | Scripts set `ro.secure=1`, `ro.adb.secure=1`, but also `ro.build.selinux=0`. The bring-up init patch allows property sets only from root/system; whether the shipped init uses it is unpublished. | Partly true, security still weak |
| "Source-built" system | Final image is assembled from unpublished overlays, a prebuilt `galcore.ko`, and a "known-good" boot image template | Mixed: source-built core, unpublished hardware layer |
| Pinned manifest allows a clean sync | 54 projects pinned; `frameworks/base`, `system/netd`, `frameworks/opt/hardware` are patched but pinned in neither manifest; `frameworks/av` appears only in the camera pins file | **Not sufficient for a clean sync** |

---

## 4. Dry-run of the kernel patches against both kernels

Method (VERIFIED): for each patch, the files it touches were extracted from the pinned tree and `git apply --check` was run in a scratch directory. This edits nothing and compiles nothing.

| Patch (SHA-256 prefix) | Files | Applies to T110K | Applies to KOL | Notes |
|---|---|---|---|---|
| `kernel-uid-routing.patch` (`7b1ad79e2192`) | 24 | clean | **clean**, one hunk at offset +7 in `net/ipv4/ping.c` | The offset is likely because KOL already has the 2014 ping-socket fix (I confirmed that fix is in KOL's `ping.c`). KOL has no UID-range code (`FRA_UID_START` absent). |
| `kernel-module-no-pic.patch` (`8350b1287a50`) | 2 | clean | **clean** | Only needed with a toolchain that defaults to position-independent code (see 5). |
| `kernel-initrd-length.patch` (`b20ba9ff15fc`) | 1 | clean | **clean** | Applies, but see 5: it encodes a tablet bootloader assumption. |
| `kernel-native-panel.patch` (`e92c16837e0c`) | 3 | clean | clean (file-mode warning only) | Applies as text, but edits code that isn't compiled for the GT-I8200 board. It also repeats the initrd patch. |

**A clean dry run means the text matches. It does not mean the patch compiles, is correct, or helps.**

---

## 5. Table of reusable fixes, required modifications and unusable components

Legend: **Reuse** = apply with at most trivial changes. **Adapt** = idea is valid but code or values must change and be tested. **Not usable** = tablet-specific or irrelevant. **Reference** = read for ideas only.

### 5.1 Kernel

| # | Item | Class | Evidence | What needs to happen for GT-I8200 |
|---|---|---|---|---|
| K1 | UID-range routing backport (`kernel-uid-routing.patch`) | **Reuse** | Dry-run clean on KOL; KOL lacks the feature; the repo's own netd patch logs UID ranges | Needed for Android 7 networking. Verify against the upstream Android kernel commit the repo cites (`0b428749…`, unverified). Build-test later. |
| K2 | Enable netfilter mark/connmark/conntrack/idletimer (from `kernel.config`) | **Adapt** | `=m` in port config, `=n` in KOL golden | Enable in the GT-I8200 config after checking Android 7.1's kernel requirements. |
| K3 | SELinux in kernel (`SECURITY`, `SECURITY_SELINUX`, `AUDIT`, `EXT4_FS_SECURITY`) | **Adapt** | On in port config, off in KOL | Decide policy (permissive vs disabled). Do not copy the port's `selinux=0` + init-patch combination as the end state. |
| K4 | `-fno-pic -fno-pie` for the Wi-Fi and netfilter modules (`kernel-module-no-pic.patch`) | **Adapt** | Dry-run clean; the need depends on the toolchain, not the device | Not needed with Samsung's original GCC 4.6 toolchain. Needed only if modules are built with an Android 4.9 toolchain. |
| K5 | Initrd length override (`kernel-initrd-length.patch`) | **Adapt / needs evidence** | Written for "the goyawifi loader supplies a fixed 16 MiB initrd span" | Only useful if the GT-I8200 bootloader hands over a fixed ramdisk span. Needs the GT-I8200 boot image layout (Phase 2). Do not copy the hard-coded size. |
| K6 | Native panel init (`kernel-native-panel.patch`) | **Not usable** | Targets `CONFIG_MACH_GOYA` and the VX5B3D LVDS bridge; the GT-I8200 compiles `lcd_s6e63m0*.o` instead | Skip. If the GT-I8200 panel doesn't light up after boot, debug its own S6E63M0 path. |
| K7 | Kernel command line (`CONFIG_CMDLINE=… goyawifi.initrd_size=1419841 goyawifi.lcd_init=1`) | **Not usable** | Hard-coded for one tablet ramdisk | Use the GT-I8200 bootloader's command line. |
| K8 | The T110K kernel tree itself | **Not usable as a base** | 103 unexplained edits vs Samsung's SM-T110 source; KOL differs in 165 files | Use KOL. Port single fixes. |
| K9 | CMA 128 MB / Etnaviv backports in T110K | **Reference** | Not used by the Android port's GPU path (it uses `galcore`) | Ignore unless the open GPU route is explored later. |

### 5.2 Android framework patches

| # | Item | Class | Evidence | What needs to happen for GT-I8200 |
|---|---|---|---|---|
| A1 | `bionic.patch`: let `/system/lib/libGAL.so` keep text relocations under Android 7 | **Reuse** | GT-I8200 `libGAL.so` has `TEXTREL` (STATIC) | Apply as is. Re-check the linker hunk still matches the pinned bionic revision. |
| A2 | `hardware-libhardware.patch`: pad `hwc_layer_1_t` to 100 bytes and add the 32-bit alpha word | **Reuse (partly verified)** | Stride 100 and list offset 20 confirmed in `hwc_prepare_gc` (STATIC); other field offsets not yet | Trace the remaining offsets (alpha at 24, crop at 28, frame at 44, fences at 68/72, alpha at 76) before relying on it. |
| A3 | `frameworks-native.patch` — HWC part (`HWComposer_hwc1.cpp`): treat types 100/101 as overlay, use pre-1.5 attribute list, `static_assert` layout checks | **Adapt** | Type 101 and stride confirmed; attribute behaviour not tested | Keep the layout asserts. Re-test the "×1000 DPI" fix. GT-I8200 has a different panel and density. |
| A4 | `frameworks-native.patch` — `Surface.cpp` legacy-EGL queue wait | **Adapt / needs evidence** | EGL worker behaviour cannot be seen statically | Add behind the existing property gate. Enable only if the buffer queue stalls on GT-I8200. |
| A5 | `frameworks-native.patch` — `FramebufferSurface` retire thread (vblank ioctl) | **Adapt / needs evidence** | Handler `FB_IOCTL_WAIT_VSYNC` exists in KOL's frame-buffer driver; ioctl number not confirmed | Confirm the ioctl value. Gated by `debug.goya.fb_retire`, so it can ship off by default. |
| A6 | `frameworks-native.patch` — `installd` changes (skip labelling and xattr errors) | **Not usable** (if SELinux is enabled) | Written for a RAM-only, no-SELinux bring-up | Drop if the GT-I8200 build runs with SELinux. |
| A7 | `frameworks-native.patch` — debug logging in `Surface.cpp` | **Not usable** | Diagnostic only | Skip. |
| A8 | `system-core.patch`: init runs without SELinux; property sets only from root/system | **Not usable as an end state** | Comments call it "temporary native bring-up" | If ever used, keep it as a bring-up-only switch. |
| A9 | `frameworks-base.patch`: `debug.hwui.partial_updates` alias; null-guard for `networkPolicy` | **Reuse (small)** | First one avoids a property-name length limit; second matches `config.disable_network` | Optional. Apply the first only if hwui partial updates glitch. |
| A10 | `frameworks-opt-hardware.patch`: opt out of GPU colour transform | **Reuse (small)** | Gated by `ro.goya.no_gpu_color` | Optional performance fix. |
| A11 | `camera-service-startup.patch`: skip missing UI sound files | **Reuse (small)** | Only matters for a minimal payload | Likely unnecessary with a full system image. |
| A12 | `netd-rule-diagnostics.patch` | **Not usable** | Debug logging | Skip. |
| A13 | `shims/legacy_binder.c` (`libshim_goyawifi_binder`) | **Reuse** | GT-I8200 `gralloc.mrvl.so` imports the same non-const `getCallingPid` symbol (VERIFIED on the file) | Rename for GT-I8200. The `LD_PRELOAD` wiring is in the init scripts (see D4). |

### 5.3 Device, product and packaging

| # | Item | Class | Evidence | What needs to happen for GT-I8200 |
|---|---|---|---|---|
| D1 | Product files (`lineage.mk`, `lineage_goyawifi.mk`, `goyawifi_init.mk`, `AndroidProducts.mk`) | **Not usable** | Tablet, Wi-Fi only, no Phone/TeleService, 600×1024, hwrotation 270, density 160, `PRODUCT_MODEL := SM-T110` | A GT-I8200 product is a phone with telephony, 480×800, and its own density. Start fresh. |
| D2 | Graphics-quirk properties: `ro.opengles.version=131072`, `ro.bq.gpu_to_cpu_unsupported=1`, `ro.zygote.disable_gl_preload=true`, `debug.hwui.partial_updates=false`, `dalvik.vm.extra-opts=-Xnorelocate`, heap sizes | **Adapt** | They are workarounds for the same GPU stack | Try as a starting set. Tune heap for the GT-I8200's 1 GB RAM (reported spec). |
| D3 | `overlay/…/config.xml` (`config_voice_capable=false`) | **Not usable** | Opposite of what a phone needs | Drop. |
| D4 | `packaging/ramdisk-init.framework.rc` | **Reference** | RAM-only bring-up with services started by properties; references helper scripts that aren't published | Use the service list as a checklist only. |
| D5 | Bring-up probes (`graphics_probe.cpp`, `surface_probe.cpp`, `binder_probe.cpp`, `HelloNougat.java`) | **Reuse as test tools** | Self-contained C++/Java; the graphics probe tests EGL, shaders, native-buffer textures | Reuse in Phase 4 to check each layer separately. Check its hard-coded library paths first. |
| D6 | Camera HAL (`goyawifi-camera/*`) | **Not usable as is / Reference** | One 2-megapixel-class sensor, fixed sizes, debug-register writes | The GT-I8200 camera needs its own driver path. Use as a template for a V4L2 + ION HAL. |
| D7 | TWRP installer (`update-binary`, `updater-script`, `build-twrp-zip.py`, `release-metadata.json`) | **Not usable** | Hard-codes `SM-T110`, `goyawifi`, `mmcblk0p15`/`p10`, exact sizes and hashes; README claims a recovery-fingerprint check it doesn't perform | Never reuse. The idea of checking model, partition links, sizes and hashes before writing is good; it must be rebuilt from the GT-I8200's real partition table. |
| D8 | Build/assembly scripts (`build-nougat-*.sh`, `assemble-full-lineage.py`, `package-full-lineage.sh`, `pack-sensor-control-boot.py`) | **Reference** | Depend on the author's host paths, an Ubuntu 16.04 chroot, a mounted `nougat-build.ext4`, and unpublished folders | Read for sequence only (core → graphics → services → ART → camera → assemble). |
| D9 | `sources/lineage-14.1-resolved-manifest.xml` (54 projects, pins) | **Adapt** | Pins LineageOS cm-14.1 revisions and AOSP `android-7.1.2_r36` for build tools | Reuse the pinned revisions as a known-good starting point. A complete manifest still has to be written. |
| D10 | `sources/wifi-source-pins.json`, `camera-source-pins.json` | **Reference** | Pin a handful of extra projects | Reuse the pins for `wpa_supplicant_8` and the others if they apply. |

### 5.4 Not provided at all (must come from GT-I8200 firmware or be written)

| Needed piece | Why it matters |
|---|---|
| Graphics, display, audio, camera, sensor, GPS blobs for the GT-I8200 | The SM-T110's blobs are neither published nor suitable. |
| Telephony (RIL, modem files, NVM) | Nothing in the SM-T110 project addresses it; it removes the phone stack. |
| Wi-Fi/Bluetooth firmware and `wpa_supplicant` config | Same Marvell SD8787 family, but board settings differ. The GT-I8200 dump has `sd8787_uapsta.bin` and `w8787_wlan_SDIO_bt_SDIO.bin` (STATIC, community dump). |
| Audio route/path configuration | The SM-T110 audio layer is unpublished. |

---

## 6. Missing source files and unpublished dependencies (VERIFIED by grep against the repo's file list)

Referenced by the repo's scripts or init files, but **absent** from the repository:

| Missing | Referenced by | Impact |
|---|---|---|
| `device/samsung/goyawifi-framework/` (BoardConfig.mk and product) | `goyawifi/BoardConfig.mk` line 3; `build-camera-source.sh` (`lunch goyawifi_framework-userdebug`) | The "tested downstream kernel/GC1000 compatibility switches" (the repo's own comment) live here. This is the single most informative missing file. |
| `goyawifi_defconfig` | `build-nougat-kernel.sh` | Exists only inside T110K (`arch/arm/configs/goyawifi_defconfig`). The repo's `kernel.config` is the final result after the script's edits. |
| `nougat-ramdisk.cpio.gz`, `ANDROID7_REFERENCE_ZIMAGE` (`kernel-reference`) | `build-nougat-kernel.sh`, `build-nougat-native.sh` | The ramdisk size is baked into the kernel command line. |
| `GOYAWIFI_WORK_DIR` folders: `framework-runtime/` (system files, `tmp/galcore.ko`, `sbin/healthd`), `wifi-`, `audio-`, `bluetooth-`, `camera-`, `hw-video-`, `brightness-`, `gps-`, `sensors-runtime/` | `assemble-full-lineage.py` | The whole hardware layer of the final image. |
| `graphics-vendor-runtime-manifest.json`, `build-art-boot-image.py` | `assemble-full-lineage.py`, `package-full-lineage.sh` | Needed to assemble the system and ART image. |
| `full-lineage-rollback/boot-internal.img` | `assemble-full-lineage.py` | A "known-good" boot image whose kernel hash is asserted (`233e4f8e…`) and whose ramdisk is repacked. |
| `sbin/internal-setup.sh`, `sbin/internal-firstboot.sh` | init rc, assembly | Not published (the assembly script shows part of the first one). |
| `goyawifi_pid_probe`, `gpio-keys.kl`, `sec_touchscreen.idc` | assembly | Tablet input maps and a helper. |
| `GoyaCamera` app and `camera.mrvl` module build files | `PRODUCT_PACKAGES` in `lineage.mk` | Only the `.java` and HAL `.cpp` are published, with no `Android.mk` or manifest. |
| `goya_storage_setup` | `PRODUCT_PACKAGES` | Not found. |
| Revisions for `frameworks/base`, `system/netd`, `frameworks/opt/hardware` | patches exist for these projects | Not pinned in either manifest. The patches' `index` lines hold only blob hashes. |
| Full list of the hundreds of other LineageOS projects | both manifests (54 projects each) | The pins are a subset. |
| Stock SM-T110 firmware | README ("must be supplied from a lawful SM-T110 firmware source") | Proprietary parts excluded by design. |
| Release ZIPs | README | Not downloaded. |

**Not reproducible as published:** any claim about the final SM-T110 image. A third party can inspect the patches but cannot rebuild the image.

---

## 7. Implications and recommended next steps

1. **Base for the GT-I8200 kernel: KOL (Koloses `44afe4c`), not T110K.** Port selected items: K1 (UID routing), K2 (netfilter options), K3 (SELinux decision), and K5 only if the boot image requires it.
2. **Graphics plan:** treat A1, A2, A3 and A13 as the core of the display work. Close the open points by tracing the remaining HWC layer offsets (A2) and confirming the vsync ioctl number (A5). Keep the legacy EGL queue (A4) and retire thread (A5) as switchable options.
3. **Do not reuse** the product, packaging, installer, camera, sensor or init-flow files (D1, D3, D6, D7, K6, K7, A6, A7, A8).
4. **Telephony, camera and audio** each need their own investigation from the GT-I8200's own files and firmware. Phase 1 gave no shortcut for any of them.
5. **Phase 2 (kernel) cannot start until the Phase 0 gaps are closed**, in particular the official Samsung GT-I8200 kernel package and stock firmware. Those are needed to:
   - Confirm KOL matches Samsung's original.
   - Extract the stock kernel config and boot-image layout, which settles K5 and the command line.
   - Read the real partition table before writing any installer.
6. **Safety carry-over:** any future installer must verify model, codename, partition links, partition sizes and image hashes, and must refuse to write if any check fails. The SM-T110 installer is a reasonable pattern but is not safe to adapt by editing values.

### What I need from you
- **Samsung access (same as Phase 0):** allow `opensource.samsung.com` and, if you want me to fetch firmware, Samsung's firmware servers in this environment's network settings, or supply the official kernel package and firmware you downloaded yourself.
- **Phone details, look only:** Settings → About device (model number, baseband version, build number) and whether an NFC option exists. Nothing is changed on the phone.

---

## Appendix A: Pinned identifiers

SHA-256 prefixes (first 12 hex characters) of the 12 patches in `jakaco/lineageos-14.1-goyawifi` at `df7ed546…`:

| File | SHA-256 prefix |
|---|---|
| `patches/android/bionic.patch` | `c460314a15e2` |
| `patches/android/camera-service-startup.patch` | `84f3359fe2c5` |
| `patches/android/frameworks-base.patch` | `47bee11958ca` |
| `patches/android/frameworks-native.patch` | `35507dd1f102` |
| `patches/android/frameworks-opt-hardware.patch` | `d001c4622ec6` |
| `patches/android/hardware-libhardware.patch` | `c399dfe90819` |
| `patches/android/netd-rule-diagnostics.patch` | `ab1582d200b8` |
| `patches/android/system-core.patch` | `f9df2c23ba71` |
| `patches/kernel/kernel-initrd-length.patch` | `b20ba9ff15fc` |
| `patches/kernel/kernel-module-no-pic.patch` | `8350b1287a50` |
| `patches/kernel/kernel-native-panel.patch` | `e92c16837e0c` |
| `patches/kernel/kernel-uid-routing.patch` | `7b1ad79e2192` |

Kernel-source pin inside the repo (`sources/kernel-source.json`): `T110-pmOS/linux_kernel_pxa988` @ `fb2f8b6cd86864c0fcac790e97a372b1772003c7` (VERIFIED to exist, "Delete strace files", 2022-06-24).

Other repositories used: Samsung SM-T110 platform source `T110-android/samsung_platform_goya` @ `41ff63eadd36a9c493b9fce07b682d2c41187cb4`; Samsung SM-T110 kernel `T110-android/samsung_kernel_goya` @ `562ba82bb07bde98d1876eb1f8fec8de019cb301`.

## Appendix B: How to repeat the key checks

```sh
# 1. Patch dry-run (replace PATCH and extract the touched files from the pinned tree first)
git apply --check --verbose PATCH

# 2. Graphics-blob structure (read-only)
readelf -d  lib/libGAL.so | grep -E 'TEXTREL|FLAGS'
nm -D --undefined-only lib/hw/gralloc.mrvl.so | grep getCallingPid

# 3. HWC layer stride (needs: pip install capstone pyelftools, in a virtualenv)
python3 -I tools/disasm_symbol.py lib/libHWComposerGC.so hwc_prepare_gc 800 | grep -nE 'mla|#0x64|#0x65'

# 4. Kernel file-level comparison
git ls-tree -r <commit>   # compare blob ids for each path between trees
```
