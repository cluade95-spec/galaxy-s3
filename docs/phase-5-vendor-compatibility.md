# Phase 5, Part A and C: vendor compatibility and remediation table

Computer-only. No ROM or kernel build, no kernel changes, no phone contact, no firmware obtained. **No proprietary file was copied into the repository or into the vendor tree**; every binary finding below was read from the community dump in a scratch folder and is stored only as metadata (names, counts). The dump is rooted and its origin is unverified, so each finding must be re-run on official Samsung firmware before anything is extracted.

Labels: **STATIC** (read from binaries), **SOURCE** (read in LineageOS `cm-14.1`, `android_bionic`, `system/core`, `system/sepolicy`, `system/media`, `hardware/*`, kernel tree at the Phase 2 commit), **DERIVED** (inferred from the above), **CLAIMED** (someone else's statement), **UNKNOWN**. Name-level symbol checks cannot see changed function signatures or class layouts.

Complexity scale (my judgment, not a measurement): **Low** = configuration or a known pattern; **Medium** = known pattern but needs debugging; **High** = new engineering with real risk; **Very high** = no precedent or depends on unobtainable inputs.

## 1. Corrections found in this phase

| Earlier statement | Finding | Evidence |
|---|---|---|
| Phase 4 manifest: `STUpdateTool_V4_4R` is a "touch/sensor firmware update tool" | It is the **ST21NFCA NFC firmware flasher** (it names `/dev/st21nfca` and an ST21NFC patch file). This phone has no ST NFC chip. Now `#EXCLUDE` | STATIC strings; kernel builds the st21nfca driver only for other boards (Phase 3) |
| The second non-PIE file `rtccd2` was not in the manifest | It is a **zram compressed-swap helper** (stock service `rtccd -a 300M`; it writes `/sys/block/zram0/disksize`). Now `#EXCLUDE`; replace with an fstab `zramsize=` entry (the kernel has `CONFIG_ZRAM=y`, `CONFIG_SWAP=y`; Android 7's `fs_mgr` parses `zramsize=`). The 300M is only a hint, not a decided size | STATIC strings; stock init; SOURCE `fs_mgr_fstab.c` |
| "sensord missing" (Phase 3/4) | `sensord` is a stock **service** (`class main`, user system) of unknown purpose and is not in the dump. The sensors HAL `sensors.mrvl.so` does **not** link to it: it reads `/dev/input` (`mpu6k_input`) directly, and the compass part loads **`libacdapi_clb.so` with dlopen**. That library is in the dump but was missed by the NEEDED-based dependency check. Now added to the manifest | STATIC strings and ELF `NEEDED`; init rc |
| Phase 4: "`gs_modem.ko` not built, a telephony module may be missing" | `gs_modem` occurs only in USB gadget code (`pxa910_f_modem.c`, `pxa910_u_serial.c`), not in the telephony drivers. Probably built in; not a missing telephony module | SOURCE (kernel tree) |
| Wi-Fi firmware option `sd8777` in Koloses | The driver's own default for this card is `mrvl/sd8787_uapsta.bin`; `sd8777` belongs to the tablet. Omit `fw_name` or set it to sd8787 | SOURCE `moal_sdio.h` |

## 2. Inventory and fix class for every incompatibility found

Fix classes: **config** (build/board setting), **compat** (small shim library), **android-own** (use Android 7's own module instead of the vendor file), **official-blob** (take the library from verified official firmware), **defer/exclude** (not needed for a first build), **blocked** (no known solution).

| # | Item | Count | Class | Notes |
|---|---|---|---|---|
| 1 | Non-PIE executables | 2 (`rtccd2`, `STUpdateTool_V4_4R`) | exclude | Neither is needed. Allow-list header (`LINKER_NON_PIE_EXECUTABLES_HEADER_DIR`) not required. |
| 2 | Libraries with text relocations | 81 in dump, 26 in manifest | config + one linker exception + sepolicy | See section 3. |
| 3 | Libraries needed but absent from the community lists | 13 (Phase 3) + 1 dlopen'd (`libacdapi_clb`) | official-blob / android-own | See section 4. |
| 4 | `libstlport` | needed by `camera.mrvl.so`, `libmarvell-ril.so` | official-blob | Removed from Android 7; cannot be shimmed. |
| 5 | `VectorImpl::reservedVectorImpl1-8`, `SortedVectorImpl::reservedSortedVectorImpl1-8` | needed by `camera.mrvl`, `libwvm`, `libdrmwvmplugin`, `libstagefright_mrvl_extractor`, `libmrvlpreprocessing`, `libFileMonitorService` and others (16 names) | compat | Empty stubs, already written (`shims/libshim_goldenvess3g`). |
| 6 | `RefBase::moveReferences` | `camera.mrvl.so` | compat | No-op stub written. Correct only if the library never relies on its effect (UNKNOWN). |
| 7 | `IMemoryHeap` destructors (D0/D1/D2 + thunks) | `camera.mrvl.so` | blocked (no design yet) | Providing wrong destructors corrupts memory; deliberately not faked. |
| 8 | 25 `CameraParameters` constants | `camera.mrvl.so` | compat (generated) | `tools/vendor/gen-camera-shim.py` reads the values from an official `libcamera_client.so`; nothing committed. |
| 9 | `IPCThreadState::getCallingPid` symbol form | graphics libs | compat | Forwarder written; wiring still TODO. |
| 10 | 3 EABI4 libraries (`libsAMRNB`, `libsAMRWB`, `libresampler`) | 3 | defer/exclude | None is required by a first-build HAL. Not in the manifest as active files (STATIC: flags 0x4000002). |
| 11 | `p2p_supplicant` (needs OpenSSL calls BoringSSL lacks) | 1 | android-own | Use Android 7's `wpa_supplicant`. |
| 12 | `audio.r_submix.default` | 1 | android-own | Android 7 builds its own. |
| 13 | Platform-only symbols in 4.2 libraries (SoundAlive, Dolby `ddpi_*`, `SamsungGLM*`, MILV, exif, ICU/XML) | ~12 libraries | official-blob (the symbols live in vendor libs missing from the lists) or defer | `libMrvlOmx`, `libsoundalive`, `libexif_jni`, `libxml2` are not first-build items. |
| 14 | `sqlite3_*` deprecated functions (6), `XML_Parse`, `XML_SetCharacterDataHandler` | `libmarvell-ril`, `libsecnativefeature` | android-own | Present in `external/sqlite` (header, no OMIT_DEPRECATED) and `external/expat` (SOURCE). Needs a build to confirm the exports. |
| 15 | `create_echo_reference` / `release_echo_reference` | `audio.primary.mrvl.so` | android-own | **Resolved by source:** cm-14.1 `system/media/audio_utils` still builds `echo_reference.c` into `libaudioutils`, and the HAL already links `libaudioutils`. |
| 16 | AOSP/Samsung classes that no longer exist in Android 7 (`AssetManager`, `AndroidRuntime`, `AudioCalibrationParser`, Skia `SkBitmap`, `RemoteDesktopService`, `bcc::*`) | `libceu`, `libOrgan`, `libsystem_server`, `abcc` | defer/exclude | Samsung apps and extras; not first-build items. |
| 17 | `crt*.o` and root artifacts in the dump | n/a | exclude | Never extract. |
| 18 | `libwtpsp`, `libparseTim`, `libMILV` etc. (modem loader) | 5 | official-blob, TEXTREL | Needed only if cellular is attempted. |

## 3. The 81 text-relocation libraries

Full table: [data/textrel-libraries.tsv](data/textrel-libraries.tsv) (path, size, relocation counts, whether in the manifest). Method: `tools/vendor/textrel-analysis.py` counts relocations whose target address lies in an executable segment (STATIC).

### What Android 7.1.2 actually does (SOURCE)
- `linker.cpp` rejects a library with text relocations only when the loading process's target SDK is above 22. With `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS` the check becomes: reject only if the target SDK **is not the platform's own value** and is above 22. Native daemons and the system process use the platform value, so they load these libraries (with a warning). Third-party apps that target SDK 23 or newer do not.
- **SELinux:** `system/sepolicy` `domain.te` forbids `execmod` rules, except that when `target_needs_platform_text_relocations` is true the rule is relaxed for `system_file` and for non-app domains. So the flag also **permits** device policy rules that give `execmod` on `system_file` to the domains that load these libraries. Without such rules, enforcing SELinux would block them. The policy itself is not written (sepolicy TODO). Permissive mode is a stop-gap that I do not recommend as a final state.

### Findings
- 81 ELF files, 11,737 relocations in code in total. Almost all are `R_ARM_RELATIVE`; a few libraries also have `R_ARM_ABS32`. 58 libraries have 10 or fewer code relocations.
- They are not fixable by me: relinking needs the vendor's object files. The only options are: allow them (flag), patch the linker for a named library, or leave the library out.

| Group | Libraries | Code relocations | Verdict |
|---|---|---|---|
| GPU user library | `libGAL.so` (needed by `libEGL_MRVL`, `libGLESv*_MRVL`, `gralloc.mrvl`, `libgcu`, `libHWComposerGC`, `libcameraengine`, `libGLESv2SC`) | 4,001 (of 4,611 total relocations) | **Adaptable with a linker exception.** Loaded into every GL app, so the flag alone is not enough for apps targeting SDK 23+. The SM-T110 `bionic.patch` exception for `libGAL.so` is the known approach (CLAIMED to work for its owner); not yet ported or tested. Also needs `execmod` in the app domain policy. |
| Camera and image | `libcodecjpegenc` (4), `libgpucsc` (10), `libsthmb` (9) | small | Loaded in the camera/media server (a platform process): covered by the flag. Camera itself is blocked for other reasons. |
| Media codecs | 14 `libcodec*` libraries (1 to 93 each) | small | Loaded by mediaserver/OMX (platform process). Not first-build items (R7 deferred). |
| Modem loader and telephony | `libMILV` (1), `libwtpsp` (2), `libwtpsp_ss` (1), `libparseTim` (1), `libippsp` (1) | 1 to 2 each | Covered by the flag (daemons). Only relevant if cellular is attempted. `libippsp` is also used by audio libraries. |
| GPS | `gps.default.so` (1), `libagps_hal.so` (1) | 1 each | Loaded by the system server; covered by the flag. |
| Audio | `lib_Samsung_Resampler`, `libSamsungPkcs11Wrapper` | 1 to 2 | Covered by the flag; not first-build items. |
| Sensors | `libacdapi_clb.so` (compass calibration, dlopen) | small | Covered by the flag (system server). |
| Samsung apps, effects, printing, face recognition, NFC | 55 libraries not in the manifest (for example `libfacerecognition` 11.9 MB, `libvtstack` 2,725 code relocations, `lifevibes`, `libcups*`, `libstmnfc`) | up to 2,814 | **Not needed. Excluded.** |
| 4.2 platform copies | `libcrypto`, `libssl`, `libz`, `libexpat`, `libgnustl_shared` | n/a | Android 7 provides its own. Never extract. |

Settings that follow from this (all still unbuilt): `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS := true` (already set), a `libGAL` linker exception, `execmod` policy for the domains involved.

Remaining uncertainty: whether other processes that load these libraries run with a non-platform target SDK is UNKNOWN until observed (system server and `mediaserver` are expected to use the platform value).

## 4. Missing dependencies and `libstlport`

- **13 libraries** the Phase 3 closure found missing from the community list: `libstlport`, `libremotedesktopservice`, `libremotedesktop_client`, `lib_SoundAlive_V01013q`, `libjnigraphics`, `libcodecddpdec`, `libMarvellWireless`, `libexif`, `libspeexresampler`, `libMILV`, `libomission_avoidance`, `libbcinfo`, `libbcc`. They are recorded in `proprietary-files.txt`; the ones Android 7 provides (`libjnigraphics`, `libexif`) are marked `#EXCLUDE`.
- **dlopen blind spot:** a NEEDED-based closure misses libraries opened with `dlopen`. A string scan of every manifest file against the dump found one real case (`libacdapi_clb.so`, dlopen'd by the sensors HAL). The others it found (`libGLESv2`, `libRS`, `libbcc.sha1`, `libhardware_legacy`) are Android's own. Rerun this scan on official firmware.
- **`libstlport`** (STATIC): required by `camera.mrvl.so` and `libmarvell-ril.so`. Android 7 no longer builds it. It is a self-contained vendor library, so the options are (a) take it from verified official firmware and package it as a vendor blob (needs no source), or (b) leave camera and RIL out. It is not among the 81 text-relocation libraries (no TEXTREL flag found). No shim can replace it.
- **`hwcomposer.mrvl.so` and `power.mrvl.so`** were omitted from both community lists; both are in the manifest now.

## 5. Subsystem assessments

Each item states what was verified, not whether it will work.

### Graphics
- EGL/GLES: Android 7's loader still finds `libEGL_*`, `libGLESv1_CM_*`, `libGLESv2_*` by name pattern in `/system/lib/egl` (SOURCE, Phase 3). No `egl.cfg` needed.
- `gralloc.mrvl.so`: module API 1.0, HAL 0.0 (STATIC); needs `libGAL`, `libgcu`, `libbinder`. `hwcomposer.mrvl.so`: module API 1.0, device HAL 1.0 (0x100), needs `libHWComposerGC`, `libEGL`, `libhardware_legacy` (STATIC). Whether Android 7's SurfaceFlinger accepts this HWC version exactly as built is UNKNOWN until run.
- Needs: libGAL exception plus `execmod` policy (section 3), the `getCallingPid` forwarder, the composer layer-record check from Phase 1 (100-byte layer record, STATIC on a community dump), galcore module with its stock parameters.
- Precedent: the SM-T110 port (CLAIMED by its owner) uses the same Vivante stack. Complexity High; uncertainty High. This is the make-or-break item for any visible UI.

### Audio
- `audio.primary.mrvl.so`: device version 2.0, equal to Android 7's minimum (STATIC, Phase 3). Its echo-reference calls are provided by Android 7's `libaudioutils` (SOURCE, new). It links Marvell/Samsung libraries (`libasound`, `libacoustic`, `libsamsungSoundbooster`, `libsamsungRecord`, `libaudiodebugtool`, `libeffects`) that must be checked against official firmware.
- Policy: stock uses a legacy `audio_policy.mrvl.so` (module API 1.0). Android 7 still has the legacy path, but struct compatibility of the legacy policy interface is UNKNOWN.
- Voice-call audio goes through `audio_path.vc.mrvl.so` and NVM calibration files that `tel_launch.sh` copies from `/system/etc/tel/ttc/`; it is therefore tied to cellular.
- Complexity Medium to High; uncertainty High for calls, Medium for media playback.

### GPS
- `gps.default.so`: module API 1.0, links only basic libraries; `libagps_hal` adds SSL and networking. UART2 `/dev/ttyS2`, `/proc/driver/sirf` (STATIC and kernel). Android 7 still supports the legacy `gps.h` interface; the HAL's interface size handling is UNKNOWN. Both libraries have a single code relocation each (covered by the flag).
- The SM-T110 owner reports GPS working with the same design (CLAIMED). Complexity Medium; uncertainty Medium.

### Bluetooth
- Kernel module `mbt8xxx.ko` registers a character device named `mbtchar0` (SOURCE, kernel `bt_main.c`). LineageOS `hardware/marvell/bt` `libbt-vendor` opens exactly `/dev/mbtchar0` (SOURCE). This is a real fit, found by reading both sides.
- The stock stack is Marvell's own (`bplus.default.so`), not Android 7's Bluedroid; moving to Bluedroid + `libbt-vendor` is a different code path (UNKNOWN). Firmware is the combined `w8787_wlan_SDIO_bt_SDIO.bin` loaded by the driver (not by `libbt-vendor`). Where the BD address comes from (`ro.bt.bdaddr_path` points to `/efs/bluetooth/bt_addr`) needs checking. aptX libraries are excluded (not needed). Complexity Medium; uncertainty Medium.

### Wi-Fi
- Kernel: `mlan.ko` (core) and `sd8xxx.ko` (glue) are two separate modules (SOURCE, `obj-m` lines in the driver Makefile; DERIVED: `sd8xxx` depends on `mlan`). With `CONFIG_CFG80211=y` and `CONFIG_WEXT_PRIV=y` the driver builds both nl80211 and wext support (SOURCE), consistent with the stock `wpa_supplicant -Dnl80211`.
- **New issue:** Android 7's `libhardware_legacy` `wifi.c` has no support for a second "SDIO interface" module (`WIFI_SDIO_IF_DRIVER_MODULE_PATH` appears in the Koloses `BoardConfig.mk` but not in cm-14.1 sources, SOURCE). It can load only one module through `WIFI_DRIVER_MODULE_PATH`. So init must load `mlan.ko` first (or `modprobe`), then the HAL loads `sd8xxx.ko`. Not yet written.
- Module options in Koloses (`cfg80211_wext`, `sta_name`, `uap_name`, `wfd_name`, `fw_name`) are real driver parameters (SOURCE); the firmware path in them must be sd8787.
- LineageOS `hardware/marvell/wlan` is gated on `BOARD_HAVE_MARVELL_WIFI` and supplicant 0.8 (Phase 4). Complexity Medium; uncertainty Medium (the SM-T110 owner reports it working on the same chip family, CLAIMED).

### Power
- `power.mrvl.so`: module API 0.2, HAL 1.0 (STATIC), links only libc and liblog, reads sysfs under `/sys/class/...`. Android 7 still has the power HAL interface at this version. The stock also runs a `powerdaemon` service. Complexity Low to Medium; uncertainty Medium (sysfs paths exist only if the kernel exposes them: not checked).

### Sensors
- `sensors.mrvl.so`: module API 1.0, "Invensense Sensors Module" (STATIC). Reads `/dev/input` with `mpu6k_input`; has accelerometer, gyroscope, geomagnetic, proximity code. Compass calibration comes from `libacdapi_clb.so` (dlopen, now in the manifest). No `sensord` link. Android 7 still supports old-style sensors modules (not rechecked at struct level). Needs the stock `/sys/class/sensor_event/...` permissions (already in `init.pxa988.rc`). Complexity Medium; uncertainty Medium. What `sensord` does is UNKNOWN (it may matter for the compass).

## 6. Part C: component-by-component remediation table

| Component | Current problem | Proposed solution | Evidence | Complexity | Remaining uncertainty |
|---|---|---|---|---|---|
| Kernel integration | Android 7 needs netfilter/UID-routing options; Lineage's config mechanism wants a change inside the kernel tree; Samsung root restrictions off in plain defconfig | Out-of-tree config fragment (unapplied), decide the Samsung options deliberately; apply only with approval to touch the kernel tree | Phase 2 build; `kernel/README.md` | Medium | Whether UID routing needs a source patch (the SM-T110 port patched it, CLAIMED) |
| Boot image / partitions | No verified offsets, partition sizes or partition table | Obtain from official firmware or the owner's read-only device report; keep as TODO | Phases 2 to 4 | Medium | Entirely unknown until firmware is available; **blocks flashing, not building** |
| Graphics (EGL/GLES, gralloc, HWC) | `libGAL` code relocations (4,001), SELinux `execmod`, `getCallingPid` symbol, HWC layer record, galcore parameters | Flag (set), `libGAL` linker exception, `execmod` policy, forwarder shim, compare composer layout; take libraries from official firmware | Section 3, 5; Phase 1 | High | Everything runtime; SurfaceFlinger acceptance of this HWC |
| Display, touch, keys | Only kernel drivers and stock rc | Keep stock permissions; `ro.opengles.version`; set density after hardware check | Phase 3/4 | Low | Panel density value |
| Wi-Fi | Two modules, one load slot; wrong firmware name in community config | init `insmod mlan.ko`, `WIFI_DRIVER_MODULE_PATH` for `sd8xxx.ko`, sd8787 firmware, `hardware/marvell/wlan` | Section 5 | Medium | Firmware/MAC file flow, supplicant behaviour |
| Bluetooth | Stock stack is Marvell's own, not Bluedroid | `hardware/marvell/bt` `libbt-vendor` over `/dev/mbtchar0` | Section 5 | Medium | BD address source, SCO/PCM settings, firmware load order |
| Audio (media) | Legacy HAL and legacy policy on Android 7; vendor libs to verify | Keep HAL 2.0 + legacy policy; resolve echo reference via `libaudioutils` (source-confirmed) | Section 5 | Medium to High | Legacy policy struct compatibility |
| Audio (calls) | Voice path depends on telephony NVM files and Marvell paths | Defer until cellular reaches registration | `tel_launch.sh` | High | Whole path |
| GPS | Legacy `gps.h` HAL; one code relocation each | Flag; keep UART setup | Section 5 | Medium | HAL interface size handling |
| Sensors | `sensord` role unknown; compass library was missed | Add `libacdapi_clb` (done); test accel/gyro/prox first; investigate `sensord` in official firmware | Section 1, 5 | Medium | Compass without `sensord` |
| Power / lights | HALs omitted from community lists; sysfs paths not checked | Include in manifest (done); check sysfs from official firmware/kernel | Section 5 | Low to Medium | Sysfs availability |
| Camera | `libstlport`; 25 constants; vector/RefBase symbols; `IMemoryHeap` destructors without design; HAL1 | Official `libstlport`, generator, shims; **design for `IMemoryHeap` needed before any attempt**; leave camera out of the first build | Phase 3/4, Section 2 | Very high | Class layout changes behind equal symbol names |
| Media codecs | 14 libraries with code relocations; Dolby/SoundAlive libs | Defer (R7) | Section 3 | Medium | Not assessed |
| Non-PIE files | `rtccd2`, `STUpdateTool` | Exclude both; zram via fstab (size TODO) | Section 1 | Low | zram size choice |
| Missing libraries | 13 + 1 dlopen'd | Official firmware, rescan after extraction | Section 4 | Low (once firmware exists) | Depends on firmware |
| SELinux policy | None written; `execmod` needs policy; permissive is only a stop-gap | Write minimal policy after first boot logs exist | Section 3 | Medium to High | Unknown denials |
| Cellular (RIL) | Request table ends at 123 while Android sends up to 137; `libstlport`; modem stack and NVM | Interposer prototype (host-tested), official `libstlport`, defer integration | [phase-5-cellular-feasibility.md](phase-5-cellular-feasibility.md) | Very high | Everything at run time; no Marvell-on-Android-5+ precedent |
| Vendor tree | Needs verified official firmware | Guarded extraction scripts exist; nothing extracted | Phase 4 | Low once firmware exists | Firmware not obtainable from this environment |

## 7. Blob policy (restated)

- No community blob is, or will be, in the final vendor tree. `extract-files.sh` refuses anything without verified provenance and rejects root artifacts and other models. The community dump is used only for analysis, in a scratch folder outside the repository.
- This phase added metadata only: names, counts and flags. The repository contains no binaries.

## 8. Limitations

- Everything is static analysis or source reading. Nothing was loaded by Android's linker, so "covered by the flag" means "the code path in `linker.cpp` allows it", not "it loads".
- The community dump may differ from official firmware (version, content, modification). All counts above can change.
- The camera class-layout issue (same symbol name, different layout) cannot be detected by name checks.
- Complexity and uncertainty ratings are judgment calls.

## 9. Recommendation

See the end of [phase-5-cellular-feasibility.md](phase-5-cellular-feasibility.md) for cellular, and the README for the overall decision. In short: **yes, advance to a first experimental ROM build attempt, with the scope limited to Wi-Fi, Bluetooth, GPS, graphics, audio playback and sensors; camera and cellular are out of the first build.** The vendor problems that have a clear fix (text relocations, the sqlite/expat/echo-reference items, non-PIE files, vector and RefBase stubs, Wi-Fi module loading) are small. The graphics libGAL exception, SELinux policy and the missing official firmware are the real gates. No flashing until the owner has approved a documented, reversible procedure.
