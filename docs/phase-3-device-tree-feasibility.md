# Phase 3: GT-I8200 Android 7.1.2 device-tree feasibility

**Date:** 2026-11-05 · **Nature:** research and computer-only preparation. No ROM or recovery was built, no phone was touched, the kernel source was not changed, no firmware was downloaded.
**Accepted starting point:** kernel `Koloses/kernel_i8200` @ `44afe4c` as the provisional kernel development base (Phase 2).
**Kept separate:** GT-I8200 (`goldenvess3g`) from GT-I8200N/L (`goldenve3g`), GT-I8200Q and GT-I8190. Where a source is for another model it is labelled.

## How to read this document

| Label | Meaning |
|---|---|
| **VERIFIED** | Checked directly in source text or git data; repeatable with the IDs given. |
| **STATIC** | Read from the structure or disassembly of a binary I did not run. The binaries are from a community dump (see 3.1). |
| **CLAIMED** | Stated by a third party (a repo, a README); I could not check it. |
| **UNKNOWN** | Not established. |

Risk levels: **Low** = precedent exists and no blocker found. **Medium** = plausible, needs porting work. **High** = depends on closed code with a known incompatibility or no precedent. **Critical** = no credible path found yet.

---

## 1. Decision (short version)

**There is enough evidence to begin constructing a GT-I8200 Android 7.1.2 device tree, as a staged, experimental effort. There is not enough evidence to promise a usable phone.**

- **Start now (computer-only):** a skeleton tree (`BoardConfig.mk`, product makefiles, `init.pxa988.rc`/fstab from the Koloses ramdisk files, kernel integration with the Phase 2 build, Wi-Fi/Bluetooth/GPS/lights/sensors/power HAL wiring), plus a vendor-file list rebuilt from official firmware.
- **Biggest blockers, in order:**
  1. **Cellular (RIL, SIM, calls, data): no precedent.** The only available stack is a closed Marvell RIL (version 7, which Android 7's RIL layer accepts) plus six Marvell daemons and a modem image that lives in a partition. Nothing in the evidence shows any Marvell-telephony phone running Android 5 or later. The one phone-class attempt I checked turned out to be a different chip vendor (section 5.8).
  2. **No verified stock firmware or partition table.** Boot-image header values, partition sizes and the exact vendor files cannot be settled without the official firmware (still blocked, see Phase 2 preparation). I invent none of them.
  3. **Camera:** the stock camera HAL needs 25 camera-parameter constants that Android 7 no longer defines, three removed library features and a removed C++ library; the SM-T110's replacement HAL is for another sensor.
  4. **Audio for calls** depends on blocker 1, and the audio HAL stack is a Marvell-specific set of plug-ins.
  5. **Closed GPU stack:** workable by the same shims the SM-T110 port used, but never shown on this phone.

If blocker 1 cannot be solved, the realistic outcome is a Wi-Fi/Bluetooth/GPS Android 7.1.2 device without calls or mobile data. That should be accepted or rejected deliberately (a question I asked in earlier phases and still need answered).

---

## 2. Audit of the existing device trees

Compared by file content (git blob hashes), 2026-11-05.

| Tree | Model it claims | What it really is | Verdict |
|---|---|---|---|
| `Gabrius99/android_device_samsung_goldenvess3g` @ `470dfde` (65 files, 2016-03) | GT-I8200 | "Starting from lt02wifi base": 8 of its files are byte-identical to the **Galaxy Tab 3 7.0 3G** (`gr8nole/android_device_samsung_lt023g`, SM-T211) tree, including `init.pxa988.tel.rc`, `init.pxa988.usb.rc`, `ueventd.pxa988.rc`, `twrp.fstab`, `egl.cfg`. Its `BoardConfig.mk` lists boot/recovery 12 MiB and system 1,507,852,288 bytes (not from a phone), Wi-Fi firmware `sd8777` (the tablet's; the phone's files are `sd8787`), `USE_CAMERA_STUB`, pre-KitKat audio flags; its `proprietary-files.txt` lists 50 files absent from its own dump. Kernel is I8200N-derived (Phase 0). | **Mostly unusable.** Reuse only config files that are identical in the Koloses tree. |
| `Koloses/device_i8200` @ `3bcf4bb` (50 files, 2016-03-08) | GT-I8200 | First commit is CM `mkvendor.sh` output. Its `rootdir` is phone-specific, not the tablet's: its telephony script starts Marvell daemons (`nvm`, `atcmdsrv`, `telmon`, `simal`), which the tablet version lacks. Includes a **genuine Samsung-built GT-I8200 kernel** (Phase 2). `BoardConfig.mk` partition sizes are placeholders (boot 64 MiB, system 6,084 MiB, userdata 21,016 MiB). | **Best available starting material**, with clean-up (below). Provenance of the ramdisk files is **CLAIMED**, though their phone-specific content and the matching kernel make a stock origin likely. |
| `zvihell/android_device_goldenve3g`, `MasterPlexus/…goldenve3g`, `dflow81/device_goldenve3g` | **GT-I8200N** | Different model (NFC variant). Share config files with Koloses. | **Reference only.** |
| `jakaco/lineageos-14.1-goyawifi` | SM-T110 tablet | Phase 1. | Reference only. |
| `misanthropy81/android_device_samsung_lt02wifi` (cm-14.1) | Tab 3 7.0 SM-T210 | 11-file work-in-progress skeleton. | Reference only. |

### 2.1 What can genuinely be reused from the Koloses tree

| Item | Verdict | Evidence / reason |
|---|---|---|
| `rootdir/init.pxa988.rc` (601 lines), `init.pxa988.tel.rc`, `init.pxa988.usb.rc`, `ueventd.pxa988.rc`, `fstab.pxa988` | **Reuse as the source of the stock boot-time behaviour**, rewritten for Android 7 init syntax and SELinux | Phone-specific content; differs from the tablet in the telephony, USB and device-node sections. Needs verification against the official ramdisk. |
| Partition numbers in the rc and `twrp.fstab`: efs p4, bootloader p6, param p8, recovery p9, boot p10, modem p11, NVM p12, preload p13, cache p14, system p15, data p16 | **CLAIMED, use as a hint only** | Differs from the I8200N-lineage fstab (system p14, cache p15, data p17). The SM-T110 uses system p15, kernel p10, recovery p9, data p16 (its repo, CLAIMED), so these devices seem to share a layout template. **No sizes anywhere.** Note the Koloses `twrp.fstab` gives p16 to both `/data` and `/preload` (an error; init says preload is p13). |
| GPU module load line: `insmod galcore.ko registerMemBase=0xc0400000 registerMemSize=0x1000 irqLine=40 contiguousSize=0x1800000 pmemSize=0x0` | **Reuse (valuable)** | The module parameters of the stock GPU driver. CLAIMED origin; consistent with the driver version found in the kernel and library (4.6.9:4651). |
| `configs/` (`asound.conf`, `audio_policy.conf`, `gps.conf`, `mrvl_gps_platform.conf`, `mrvl_agps_default.conf`, `media_profiles.xml`, `gfx.cfg`, `dms.cfg`) | **Reuse after review** | Identical in the Gabrius99 tree but not in the tablet tree, so not copied from the tablet. |
| `consumerir/`, `health/healthd-mrvl.cpp`, `cmhw/…/SerialNumber.java`, `bluetooth/bdroid_buildcfg.h` | **Review** | Old CM-era code; `consumerir` is questionable for a phone with no IR (UNKNOWN). |

### 2.2 Things in the existing trees that are copied from other devices or contradict the hardware

| Item | Problem | Evidence |
|---|---|---|
| `ro.stollmann.nfc.init "PORT=/dev/st21nfca IOTYPE=I2C"` in Koloses `init.pxa988.rc` | ST NFC chip property; GT-I8200 has no ST chip driver on its board. Leftover from a Marvell reference board. | `drivers/nfc/st21nfca.c` is built only for other boards (`board-emeidkb.c`, `board-helandkb.c`). |
| `ro.cm.hardware.cabc=/sys/class/mdnie/mdnie/cabc` in `device_i8200.mk` | The panel is an AMOLED (S6E63M0); `CONFIG_LDI_SUPPORT_MDNIE` is not set and the genuine kernel has no mdnie strings. | VERIFIED (kernel config + image strings) |
| Camera tuning files `ov5647_*`, `ov8825_*`, `lsi3h5_*`, `media_profiles.xml_for5640`; touch maps `elan-ts.idc`, `ft5306-ts.idc` in the Koloses proprietary list | Sensors and touch controllers of Marvell reference boards, not of this phone (kernel enables S5K4ECGX, SR030PC30, Atmel mXT224S). | VERIFIED against the kernel configuration |
| `sd8777` Wi-Fi firmware names (Gabrius99) | Tablet chip. The phone files are `sd8787_uapsta.bin` and `w8787_wlan_SDIO_bt_SDIO.bin`. | VERIFIED (dump + kernel `sd8787` driver) |
| `DEFAULT_PROPERTY_OVERRIDES ro.secure=0 ro.debuggable=1` | Debug-build defaults, wrong for a release ROM | VERIFIED |
| `USE_CAMERA_STUB`, `BOARD_HAVE_PRE_KITKAT_AUDIO_BLOB`, `WPA_SUPPLICANT_VERSION := VER_0_8_X` (Gabrius99/zvihell) | CM11/12-era flags; do not map to Lineage 14.1 | VERIFIED in `BoardConfig.mk` |

---

## 3. Audit of the proprietary vendor files

### 3.1 The dump and how far it can be trusted

Source: `Gabrius99/proprietary_vendor_samsung_goldenvess3g` @ `61139fc` (a copy of a `/system` partition). **Not usable as a source of blobs** for the project; used here only to learn structure.

| Check | Result |
|---|---|
| Files | 1,124: 599 ELF, 525 data/config |
| Model identity | The modem RIL carries the build path `out/target/product/goldenvess3g/…` (GT-I8200), while the GT-I8200N dump has `goldenve3g`. Graphics, audio, camera and sensor binaries are byte-identical between the two dumps. (VERIFIED, Phase 0) |
| Origin / firmware version | UNKNOWN (no `build.prop`) |
| **Contaminated by root tools** | `bin/.ext/.su`, `etc/init.d/99SuperSUDaemon`, `etc/install-recovery.sh` → copied from a rooted phone. Never reuse these. (VERIFIED) |
| Contains stock Android 4.2 platform files | `bin/surfaceflinger`, `app_process`, `servicemanager`, framework libraries and so on. These are **not vendor files** and must not be reused. (VERIFIED) |
| Build objects accidentally included | `lib/crtbegin_so.o`, `lib/crtend_so.o` (relocatable objects) |

### 3.2 Architecture and Android 7 loadability (all 599 ELF files)

| Property | Result | Consequence for Android 7.1.2 |
|---|---|---|
| Architecture | All 599: 32-bit ARM, EABI5. Flags `0x5000000` (553), `0x5000002` (43 executables), `0x4000002` = older EABI4 (3: `libsAMRNB.so`, `libsAMRWB.so`, `libresampler.so`) | Matches an `armeabi-v7a` build. The 3 EABI4 libraries are old; they are the only odd ones. |
| Executables | 117 position-independent; **2 are not**: `bin/STUpdateTool_V4_4R`, `bin/rtccd2` | Android 7's linker aborts non-PIE executables ("only position independent executables (PIE) are supported") unless built with a non-PIE allow-list (`LINKER_NON_PIE_EXECUTABLES_HEADER_DIR`, VERIFIED in `bionic/linker`). `rtccd2` (a memory-compression daemon started by init) and `STUpdateTool` (a touch/sensor update tool) will not run as they are. Neither is essential. |
| **Text relocations** | **81 libraries**, including `libGAL.so` (GPU), `gps.default.so`, `libagps_hal.so`, about a dozen media codecs (`libcodec*`), `libMILV.so` and `libparseTim.so` (both used by the modem loader) | Android 7 rejects text relocations for apps targeting API above 22. Needs the board flag `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS` and the `libGAL.so` exception from the SM-T110 patch (Phase 1). |

### 3.3 Link-level compatibility with Android 7.1.2

I checked the 145 vendor files that the Koloses list names (226 entries; 4 are not in the dump) plus `hwcomposer.mrvl.so` and `power.mrvl.so`. For each I resolved every undefined symbol against: Android 7's ARM bionic export lists (from `LineageOS/android_bionic` cm-14.1, VERIFIED), the other vendor files, and a name index of the Android 7 sources (`system/core`, `frameworks/native`, `frameworks/av`, `hardware/ril`, `hardware/libhardware*`). **This is name-level checking: it finds removed APIs reliably but cannot see changed signatures or changed class layouts.** A symbol found by name is therefore not proof that it works.

| Result | Count |
|---|---|
| Distinct undefined symbols | 2,525 |
| Provided by other vendor files | 1,415 |
| Provided by bionic (Android 7) | 465 |
| Found by name in Android 7 sources | 342 (+ 174 data members and class entries found or reviewed below) |
| At risk (not found in Android 7 sources, or only in stock 4.2 libraries) | about 130 symbols in **26 of the 145 files** |

**Concrete incompatibilities found** (each verified in the Android 7 source or binary):

| Vendor file | Problem | Source of evidence |
|---|---|---|
| `lib/hw/camera.mrvl.so` | **25 `CameraParameters` constants do not exist in Android 7** (contrast/saturation min/max, `ISO_MODE_*`, `HDR_MODE_*`, burst-capture keys, three pixel formats), imported from the stock `libcamera_client`. | Compared with `frameworks/av/camera/CameraParameters.cpp` (VERIFIED) |
| same | Imports `VectorImpl::reservedVectorImpl1–8` and `SortedVectorImpl::reservedSortedVectorImpl1–8` (removed from Android 7's `libutils`), `RefBase::moveReferences` (only a comment remains), `IMemoryHeap::~IMemoryHeap()` (no definition in `libbinder`) | `rg` over `system/core`, `frameworks/native` (VERIFIED) |
| 8 files: `camera.mrvl.so`, **`libmarvell-ril.so`**, `libsecnativefeature.so`, `abcc`, Widevine libraries | Need `libstlport.so`, which Android 7 does not ship | No `libstlport` module in any cloned Android 7 repo; the dump has the 4.2 copy (VERIFIED) |
| `bin/p2p_supplicant` | Needs OpenSSL functions that Android 7's TLS library (BoringSSL) lacks | Not reusable; use Android 7's own `wpa_supplicant` |
| `libmarvell-ril.so` | Imports six old `sqlite3_*` functions (`sqlite3_prepare`, …) | UNKNOWN whether Android 7's SQLite still exports them |
| 13 files not in the Koloses list but required by listed files (transitively): `libstlport`, `libMILV` (modem image loader, needed by `cploader` and `eeh`), `libMarvellWireless`, `libomission_avoidance` (needed by `atcmdsrv`), `libcodecddpdec`, `libbcc`, `libbcinfo`, `libexif`, `libspeexresampler`, `lib_SoundAlive_V01013q`, `libjnigraphics`, `libremotedesktopservice(_client)` | The proprietary list is **incomplete** | Dependency closure of the `NEEDED` entries (VERIFIED) |
| `hwcomposer.mrvl.so`, `power.mrvl.so` | **Present in the dump but absent from the Koloses and Gabrius99 lists** (display composer and power HAL) | VERIFIED |
| `bin/sensord` | Started by the stock `init` (`service sensord /system/bin/sensord`) and listed by Gabrius99, but **not in the dump**; its config files are | VERIFIED |

Other file-quality notes: `bin/cp`, `bin/smd`, `xbin/iwconfig` and `xbin/zipalign` are listed but missing; the list contains `system_server` and `libsystem_server.so` (platform files that must not come from 4.2); `libxml2.so` (Android 7 has its own).

### 3.4 Duplicates and consistency between GT-I8200 and GT-I8200N dumps

| File class | GT-I8200 vs GT-I8200N |
|---|---|
| GPU/EGL/gralloc/HWC, audio HAL, camera HAL, sensors, libril, libsecril-client | byte-identical |
| `libmarvell-ril.so` | different (built per codename) |
| NFC | **GT-I8200 dump has no NFC HAL, firmware or `android.hardware.nfc` permission file; the GT-I8200N list does** (`nfc.PXA986.so`, `libpn547_fw*.so`). The two NFC-named libraries in the GT-I8200 dump are generic Samsung libraries. Strong sign the GT-I8200 has no NFC (see 5.9). |

---

## 4. Boot image requirements (from evidence only)

| Item | Evidence | Status |
|---|---|---|
| Kernel format | ARM `zImage`, gzip, 3.9 MB (Phase 2 build, and the genuine image) | VERIFIED |
| Kernel base address and page size | `BOARD_KERNEL_BASE 0x10000000`, `BOARD_KERNEL_PAGESIZE 2048` in every community tree, including the `mkvendor` one (which reads them from a real boot image) | CLAIMED, consistent |
| Ramdisk offset | **Conflict:** `0x01000000` (Gabrius99, zvihell) vs `0x11000000` (MasterPlexus, dflow81) | UNKNOWN; read from the stock boot image |
| Command line | Kernel default (`CONFIG_CMDLINE_FROM_BOOTLOADER=y`): `initrd=0x01100000,1m rw androidboot.console=ttyS1 console=ttyS1,115200 panic_debug`; community `BOARD_KERNEL_CMDLINE` empty. The bootloader appears to supply the command line. | UNKNOWN what it supplies |
| Device tree | **None.** Board-file kernel: `# CONFIG_USE_OF is not set`, machine `GOLDEN` ("PXA988", ID 3907) | VERIFIED |
| Partition names | `KERNEL` (boot), `RECOVERY`, `SYSTEM`, `CACHE`, `USER`, `EFS`, `NVM`, `MODEM`, `PRELOAD` (fstab by-name under `sdhci-pxav3.2`) | CLAIMED, consistent across trees |
| **Partition sizes** | Three conflicting sets (Phase 2 preparation, section 5). Boot 12 / 16 / 64 MiB; system 1,438 / 1,521 / 6,084 MiB. | **UNKNOWN. Not used.** Needs the PIT file or a read-only partition listing. |
| Samsung boot-image trailer or signature | not established | UNKNOWN |
| Binder protocol | Kernel 3.4.5 uses protocol 7. Android 7's `libbinder` and `servicemanager` are built with `BINDER_IPC_32BIT=1`, which selects protocol 7. | VERIFIED: compatible |
| Kernel features Android 7 needs | UID-range routing (absent in this tree), netfilter mark/connmark modules (off), SELinux (off), cgroups (off); decisions in Phase 1 and 2. The SM-T110 port reports booting without cgroups (CLAIMED). | Decisions pending |
| Modules | 20 vendor modules compile with the original toolchain (Phase 2): `galcore`, `mlan`, `sd8xxx`, `mbt8xxx`, modem interfaces (`msocketk`, `ccinetdev`, `cploaddev`, `seh`, `citty`, `cci_datastub`, `diag`, `usimeventk`, `hwmap`), `physrw`, `geu` | VERIFIED |

The stock boot image and the real partition table are required before any boot image or installer layout is designed.

---

## 5. Hardware to Android 7.1.2 HAL and framework mapping

Hardware identity comes from the kernel board code and configuration (VERIFIED) and the stock kernel's compiled-in drivers (STATIC).

### 5.1 Display and GPU

| | |
|---|---|
| Hardware | Samsung S6E63M0 AMOLED 480×800, 52×86 mm (`board-golden-display.c`); Marvell `pxa168fb`; Vivante GC1000 (`galcore` 4.6.9 build 4651) |
| Android 7 needs | `gralloc`, `hwcomposer` (HWC 1.x), EGL/GLES 2.0 libraries, a framebuffer device |
| Stock pieces | `gralloc.mrvl.so` (imports the non-const `IPCThreadState::getCallingPid`; needs `libGAL`, `libgcu`, `libbinder`), `hwcomposer.mrvl.so` → `libHWComposerGC.so`, `libEGL_MRVL.so`, `libGLESv1_CM_MRVL.so`, `libGLESv2_MRVL.so`, `libGAL.so` (`$VERSION$4.6.9:4651$`), `libgputex.so`, `libgcu.so` |
| Findings | Layer stride 100 bytes, list offset 20, extra composition types, text relocations and the binder symbol all match the SM-T110 patches (Phase 1, STATIC). `pxa168fb.c` is identical to the SM-T110 kernel's. GLES 2.0 only (Android 7 minimum). |
| Missing | Proof on this phone; remaining HWC layer-field offsets; the GT-I8200 panel's density value (do not copy the tablet's 160) |

### 5.2 Wi-Fi and Bluetooth

| | |
|---|---|
| Hardware | Marvell 88W8787 combo on SDIO (`MMC2`, `WLAN_PD` GPIO 51, `BT_REG_ON` GPIO 86) |
| Android 7 needs | `wpa_supplicant` with the nl80211 driver, a Wi-Fi HAL path, `libbt-vendor` for Bluedroid |
| Available | Firmware `sd8787_uapsta.bin`, `w8787_wlan_SDIO_bt_SDIO.bin` (dump); kernel modules `mlan.ko`, `sd8xxx.ko`, `mbt8xxx.ko` **build** (Phase 2); LineageOS `hardware/marvell/wlan` (nl80211 driver-command library, gated on `BOARD_HAVE_MARVELL_WIFI`) and `hardware/marvell/bt` (`libbt-vendor`) **both have `cm-14.1` branches** (VERIFIED); the SM-T110 port reports Wi-Fi and Bluetooth working with the same chip family (CLAIMED) |
| Missing | The stock `MarvellWirelessDaemon` and `macloader` flow (needs `libMarvellWireless`, `libmedia`); firmware/MAC handling (`ro.bt.bdaddr_path /efs/bluetooth/bt_addr`) |
| Do not reuse | `p2p_supplicant` (OpenSSL), `wpa_supplicant.conf` of the tablet |

### 5.3 Audio

| | |
|---|---|
| Hardware | Marvell 88PM805 codec, ALSA; voice paths go through the modem (GSSP) |
| Stock pieces | `audio.primary.mrvl.so`, `audio_policy.mrvl.so`, six `audio_path.*.mrvl.so` plug-ins, `libasound` + ALSA plug-ins, Marvell/Samsung audio libraries (`libaudiosa`, `libacoustic`, `libsoundalive`, …), config XML/NVM files |
| Findings | `audio.primary.mrvl.so` sets its device version to `0x200` (2.0, STATIC), exactly Android 7's minimum (`AUDIO_DEVICE_API_VERSION_MIN`, which rejects anything older, VERIFIED in `AudioFlinger.cpp`). The first part of `struct audio_hw_device` has the same order as in the stock era (VERIFIED). **Android 7 still contains the legacy audio-policy path** (`USE_LEGACY_AUDIO_POLICY`, `AudioPolicy*ImplLegacy.cpp`, VERIFIED), so `audio_policy.mrvl.so` is usable. |
| Missing | Runtime behaviour; `create_echo_reference` (from `libaudioutils`, unverified); voice-call routing, which depends on the RIL |

### 5.4 Camera

| | |
|---|---|
| Hardware | Rear Samsung S5K4ECGX 5 MP with autofocus (`s5k4ecgx_jcam`), front SR030PC30 VGA (kernel config; the board file also carries options for other sensors, so the fitted parts are UNKNOWN until read from the firmware or phone) |
| Stock pieces | `camera.mrvl.so` (camera HAL v1, module API 1.0), `libcameraengine.so`, JPEG codecs, tuning/scene files |
| Findings | Android 7 still runs HAL 1 devices (`CAMERA_DEVICE_API_VERSION_1_0` in `CameraService.cpp`, VERIFIED). The HAL needs the compatibility items in 3.3 (25 constants, vector shims, `libstlport`, stock `libcamera_client` behaviour). The SM-T110 camera HAL is for a different sensor (SR200PC20M, fixed sizes) and cannot be reused. |
| Missing | A shim library; a decision about the camera client ABI; official tuning files |

### 5.5 Sensors

| | |
|---|---|
| Hardware | InvenSense MPU6500 accelerometer/gyro, ALPS HSCD compass, GP2A proximity (kernel config) |
| Stock pieces | `sensors.mrvl.so` ("Invensense Sensors Module", needs only `libcutils`, `libdl`), `etc/sensor_config.xml`, `sensord_cfg_axis` |
| Findings | Android 7's `SensorDevice` accepts old HAL versions with reduced features (VERIFIED). The module's runtime version was not determined. |
| Missing | **`sensord` binary** (not in the dump); proof the module works without it; light sensor (UNKNOWN) |
| Do not reuse | The SM-T110 accelerometer fix (`/sys/class/input/input4/…`, BMA25x tablet part) |

### 5.6 GPS

| | |
|---|---|
| Hardware | External GPS on UART2 (`/dev/ttyS2`), power/reset via `/proc/driver/sirf` (kernel `board-golden.c`: `GPS_UART`, `AGPS_RESET`, `AGPS_ONOFF`, 1.8 V LDO) |
| Stock pieces | `gps.default.so` ("MRVL GPS Module", text relocations), `libagps_hal.so` (needs `libssl`/`libcrypto`), `mrvl_gps_platform.conf`, `mrvl_agps_default.conf`, `gps.conf` |
| Findings | The SM-T110 port uses the same arrangement (`/dev/ttyS2`, `/proc/driver/sirf`) and reports a fix (CLAIMED). |
| Missing | Check `libagps_hal` against Android 7's TLS library; permissions on `/dev/ttyS2` and `/proc/driver/sirf` |

### 5.7 Lights, power, vibrator, charging

| | |
|---|---|
| Stock pieces | `lights.mrvl.so` ("Samsung lights Module", in `vendor/lib/hw/`, needs `libsecril-client`), `power.mrvl.so` (power module API 0.2, which Android 7 defines, VERIFIED), `healthd` charger code in the tree |
| Findings | The lights module's dependency on the Samsung RIL client library ties it to the telephony stack. Power HAL looks simple. |
| Missing | Whether lights works without the stock RIL client; battery/fuel-gauge integration (rev02: 88PM822 fuel gauge, RT9455 charger) in Android 7 `healthd` |

### 5.8 Cellular modem, RIL and SIM

| | |
|---|---|
| Hardware | Marvell communication processor with shared-memory interface (`msocket`); firmware in the **`MODEM` partition**, NVM data in partition p12 (CLAIMED numbers) |
| Stock pieces | `libmarvell-ril.so`, `libril.so`, `libsecril-client.so`, daemons `nvm`, `diag`, `atcmdsrv`, `eeh`, `cploader`, `vcm`, `simal`, `tel_launch.sh`, `telmon`; libraries `libMILV`, `libmtelif`, `libsocketsvr`, `libsimal`, `libparseTim`; ~44 config/NVM files under `etc/tel`; kernel modules (built in Phase 2). `rild.libpath /system/lib/libmarvell-ril.so` in the stock init. |
| Findings | `libmarvell-ril.so` exports `RIL_Init`; its radio-function table reports **RIL version 7** (STATIC: the structure at file offset `0xa2b90` whose `onSupports` function returns 1 for everything). **Android 7's `libril` accepts versions 6 to 12** (`RIL_VERSION_MIN 6`, `RIL_VERSION 12`, VERIFIED) and has version-specific handling below 12 (VERIFIED), so the version gate passes. The Marvell RIL imports only two symbols from the stock `libril` (`requestToString`, `radioStateToString`), both present in Android 7's `hardware/ril`. It needs `libstlport`, six old `sqlite3` functions and the stock Samsung support library `libsecnativefeature`. The stock `libril` also carries dual-SIM extras (`RIL2_register`, `g_rilcSimCard`/`g_rileSimCard`), so SIM count is UNKNOWN. **No Marvell-specific `RIL.java` class exists in LineageOS 14.1's `frameworks/opt/telephony`** (VERIFIED by search). |
| Precedent | **None found.** The SM-T110 build removes the phone stack. The `baffinlite` (GT-I9060) tree that my earlier summary described as a related Marvell design uses a **Broadcom** RIL (`libbrcm_ril.so`, `SamsungBCMRIL`), so it is not a Marvell precedent (correction to the Phase 0 research notes). |
| Missing | Everything that proves the RIL's requests and responses match Android 7's expectations; modem-start sequencing (six daemons, CP image load, NVM mount) under Android 7 init; the data path (`ccinetdev`, `cci_datastub`) with Android 7 `netd`; vendor-specific request codes (UNKNOWN); the radio-side audio path for voice |
| Do not reuse | Stock `rild` and `libril` binaries (Android 4.2); the tablet's telephony rc |

### 5.9 NFC

The GT-I8200 dump has no NFC HAL, firmware or permission file; the kernel compiles a PN547 driver for the shared configuration; the GT-I8200N list carries NFC blobs. **Assume no NFC on GT-I8200** (STATIC, strong); confirm from the phone's Settings. Drop the ST NFC property and any NFC packages.

### 5.10 Touch, keys, media, storage

| | |
|---|---|
| Touch | Atmel mXT224S (firmware compiled into the stock kernel: `_fw_atmel_mxt224s_fw_bin`, STATIC) plus TC360 touch keys. Kernel drivers only; low risk. |
| Media codecs | `libMrvlOmx.so`, ~17 `libcodec*` (text relocations), Marvell stagefright extractor (`libstagefright_mrvl_extractor`: 18 symbols not found in Android 7's `libstagefright`), Widevine L3 (needs `libstlport`). Hardware video decode is a separate effort; software codecs from Android are the fallback. |
| Storage | `fstab.pxa988` by-name entries; internal storage is `/data/media` with `sdcard` FUSE; external SD on `mmc1` (CLAIMED). Android 7 `vold` needs rewrite of the fstab. |
| SELinux | Stock kernel has none. Policy work needed (Phase 2 finding: the SM-T110 port runs without it). |

---

## 6. Compatibility table

| Component | Available source or binary | Evidence of compatibility | Missing requirements | Risk |
|---|---|---|---|---|
| Kernel base | Koloses `44afe4c`, built with the original toolchain | Code matches a genuine GT-I8200 kernel (Phase 2) | Android 7 options (UID routing, netfilter, SELinux decision); official source comparison | **Low** |
| Boot image / partitions | Community hints; no stock image | Names agree; header values conflict; sizes conflict | Stock `boot.img`, real partition table | **High** (information) |
| Display, GPU | Vivante stack in dump; `galcore` builds | Library version matches driver; HWC/EGL/gralloc quirks match SM-T110 patches (static) | Shims; proof on phone; density | **Medium** |
| Wi-Fi | `sd8787` firmware; modules build; Lineage `hardware/marvell/wlan` | Same chip family as the SM-T110 port (CLAIMED) | Firmware/MAC flow; Android 7 supplicant config | **Medium** |
| Bluetooth | `mbt8xxx` module; Lineage `marvell/bt` `libbt-vendor` | Same as above | Vendor daemon replacement; address file | **Medium** |
| Audio (media) | Marvell HAL v2.0 + plug-ins; legacy policy supported | HAL version meets Android 7 minimum; struct order matches | Runtime proof; echo-reference library | **Medium** |
| Audio (calls) | same, via modem | none | Depends on RIL | **High** |
| Camera (rear/front) | `camera.mrvl.so` HAL1 | Android 7 still supports HAL1 | 25 constants, vector shims, `libstlport`, stock `libcamera_client` behaviour | **High** |
| Sensors | InvenSense HAL module | Android 7 accepts old HAL versions | `sensord` missing; runtime version | **Medium–High** |
| GPS | Marvell GPS HAL, UART2 | Same design as SM-T110 (CLAIMED) | TLS library check; permissions | **Medium** |
| Lights / power / health | `lights.mrvl.so`, `power.mrvl.so` | power API 0.2 accepted | lights depends on Samsung RIL client; battery integration | **Medium** |
| **RIL, SIM, calls, data** | Marvell RIL v7 + 6 daemons + kernel modules + modem image in partition | RIL version accepted by Android 7 `libril` | Everything runtime; `libstlport`, sqlite, request compatibility; init sequencing; data path | **Critical** (no precedent) |
| NFC | none (probably no hardware) | no NFC files in GT-I8200 dump | none | **Low** |
| Touch, touch keys | kernel drivers | firmware inside stock kernel | key layouts, `idc` | **Low** |
| Video decode/encode | Marvell OMX + codecs | none | Android 7 stagefright ABI | **High** (can fall back to software) |
| SELinux policy | none | n/a | Write from scratch or run permissive | **Medium** |
| Vendor file list | Rebuilt from official firmware | Current lists incomplete/contaminated | Official firmware | **Medium** |

---

## 7. What could realistically work, what needs porting, what has no credible solution

| Class | Components |
|---|---|
| **Could realistically work** (precedent or low risk, subject to testing) | Kernel base; touch and keys; Wi-Fi; Bluetooth; GPS; power; NFC (not present) |
| **Needs porting** (known incompatibilities with specific fixes) | Display/GPU (shims from the SM-T110 work, re-verified); audio media path (legacy policy path); sensors; lights; storage and init; SELinux; non-PIE and text-relocation handling; camera (substantial shim work) |
| **No credible solution yet** | Cellular voice, SMS and mobile data; call audio; hardware video codecs. These depend on closed Marvell code with no Android 7 precedent. They are not ruled out, but I have no evidence that they can be made to work. |

---

## 8. Biggest blockers, restated

1. **Cellular stack** (critical).
2. **Missing official firmware and partition table** (information blocker for boot image, vendor list and installer).
3. **Camera ABI gaps** (high).
4. **Everything is unproven on hardware.** All "works" claims in this document are about loadability and source compatibility, not behaviour.

### What I need from you

1. **Permission to continue with the computer-only device-tree skeleton**, or a decision to stop.
2. **Samsung access or the official files** (kernel package and `I8200XXUAPB1` firmware with checksums), unchanged from Phase 2.
3. **A decision on a Wi-Fi/Bluetooth/GPS-only fallback**, in case the cellular stack cannot be made to work.
4. **Phone details (look only):** model number, baseband version, build number, and whether an NFC option exists.

---

## 9. Method and reproducibility

- Device-tree comparison: SHA-1 of every file per tree (scripts kept in the scratch area, not committed).
- Vendor audit: `pyelftools` over every ELF in the dump (machine, flags, type, `NEEDED`, text relocation, undefined/defined symbols); `c++filt` for demangling; Android 7 exports from `bionic/libc/libc.arm.map`, `libm.arm.map`, `libdl.arm.map`; name index from LineageOS cm-14.1 `bionic` (`ed81e37`), `system/core` (`ae76011`), `frameworks/native` (`a2efd4f`), `frameworks/av` (`9988512`), `hardware/ril` (`d8fb8ff`), `hardware/libhardware` (`ef9fc79`), `hardware/libhardware_legacy` (`a79094a`), `hardware/marvell/wlan` (`d00e951`), `hardware/marvell/bt` (`f4b8911`), `frameworks/opt/telephony` (`3cbef75`). These are the same revisions the SM-T110 port pins.
- HAL details: `tools/disasm_symbol.py` (Phase 1) and `capstone` disassembly of module `open()` functions and the RIL radio-function table; nothing was executed.
- Limits of this audit: name-level symbol matching; community dump of unverified origin; no stock firmware; no runtime test of any kind.

## 10. Sources

- Device trees and dumps: Gabrius99 (`470dfde`, vendor `61139fc`), Koloses `device_i8200` (`3bcf4bb`), zvihell (`2adaa3c`, vendor `21fb3b5`), MasterPlexus, dflow81 (`3e7e45c`), `gr8nole/android_device_samsung_lt023g` (`d88aaa6`), `misanthropy81/android_device_samsung_lt02wifi`, `jakaco/lineageos-14.1-goyawifi` (`df7ed54`), `Alexandre4119/android_device_samsung_baffinlite` (cm-13.0, used only to correct an earlier statement).
- LineageOS cm-14.1 repositories listed in section 9 (`https://github.com/LineageOS/…`).
- Kernel base and build: `docs/phase-2-kernel-build.md`; kernel/firmware identity: `docs/phase-2-preparation.md`.
