# Feasibility Report: LineageOS 14.1 (Android 7.1.2) for Samsung GT-I8200

**Target:** Samsung Galaxy S III Mini Value Edition, **GT-I8200**, codename `goldenvess3g`, product `goldenvess3gxx`
**Platform:** Marvell PXA986/PXA988 family SoC, Vivante GC1000 GPU, Linux 3.4.5, ARMv7 32-bit, stock Android 4.2.2
**Report date:** 2026-11-04 · **Milestone:** 1 (research only, nothing built or flashed)

---

## 1. Short answer

**A basic, usable Android 7.1.2 build looks technically possible. Phone calls and mobile data are the big unknown, and nobody has shown them working on this chip family under Android 7.**

In plain terms:

- **No Android 7 ROM exists for the GT-I8200 today.** The only GT-I8200 community projects stopped at Android 4.2/4.4 experiments or ended unfinished around 2016–2017.
- **The strongest reason for optimism:** in November 2026 someone published an experimental LineageOS 14.1 build for the **Samsung Galaxy Tab 3 Lite (SM-T110)**. That tablet uses the same Marvell PXA986 chip, the same GPU, and the same Linux 3.4.5 kernel. Its author says display, GPU acceleration, Wi-Fi, Bluetooth, audio, camera and GPS work on their tablet. I have **not** verified that claim. It is self-reported and tested on one tablet. If it holds up, most of the hardest graphics problems for this chip have already been solved and can be studied.
- **The biggest risk:** that tablet is Wi-Fi only. **SIM, calls and mobile data have never been shown working** on any PXA986 phone running Android 5 or later, as far as I could find. The phone's modem software (the "RIL") was written for Android 4.2 and may not cooperate with Android 7. If it doesn't, the result would be a "Wi-Fi only" phone.
- **Expected effort:** this is a multi-month project for someone experienced with Android porting. I can do most of the source-code research and build work in this environment. Testing on real hardware will eventually need a phone, and you have asked me not to touch yours. See section 8.

| Feature | Likelihood it can be made to work | Why |
|---|---|---|
| Boot to home screen | **Likely** | Same chip and kernel already booted Android 7 on the SM-T110 (self-reported) |
| Display / GPU acceleration | **Likely, with work** | Same GPU blobs and kernel driver family as SM-T110 |
| Touchscreen | **Likely** | Standard kernel driver (Atmel mXT224S), no special userspace needed |
| Wi-Fi | **Likely** | Same Marvell SD8787 chip and firmware family; LineageOS has Marvell Wi-Fi code |
| Bluetooth | **Probable** | Same Marvell combo chip; works on SM-T110 per its author |
| Audio (speaker, headphones, mic) | **Probable, with work** | Old Android 4.2 audio blobs need adapting; done on SM-T110 per its author |
| Camera | **Uncertain** | Different camera sensor from the tablet; old camera blobs need shims |
| SIM / calls / SMS | **High risk, unproven** | Android 4.2 Marvell+Samsung modem blobs; no Android 7 precedent on this chip |
| Mobile data | **High risk, unproven** | Depends on the same modem stack as calls |
| GPS, sensors | **Probable** | Worked on SM-T110 per its author; phone has extra sensors (proximity, compass) |
| Security (SELinux) | **Will be weak** | Stock kernel has SELinux turned off; SM-T110 port also runs without it |

"Likely" or "probable" here means "there is evidence it has been solved on closely related hardware". It does **not** mean "works on GT-I8200". Nothing has been shown working on GT-I8200 under Android 7.

---

## 2. Getting the device identity right

Three similar-looking phones are easy to mix up. Mixing them up is the most common way old forum ROMs brick phones.

| Model | Codename | Chip | Relation to our target |
|---|---|---|---|
| **GT-I8200** (our target) | `goldenvess3g` / product `goldenvess3gxx` | Marvell PXA986 family | **Target** |
| GT-I8200N | `goldenve3g` / product `goldenve3gxx` | Marvell PXA986 family | **Different variant.** Has NFC (kernel enables `CONFIG_NFC_PN547`). Most GitHub sources are for this one. |
| GT-I8190 (original S III Mini) | `golden` | ST-Ericsson NovaThor U8420 | **Completely different chip.** Its ROMs (including LineageOS 14.1) cannot be used. Per search snippet, its LineageOS 14.1 XDA thread itself lists GT-I8200 as unsupported. |

**About "PXA988" vs "PXA986":** both names show up. The device trees say `TARGET_BOOTLOADER_BOARD_NAME := PXA986`, the kernel configs are named `pxa986_golden_*`, and the boot files are named `*.pxa988.rc`. PXA986 and PXA988 are variants of the same Marvell chip family and share one kernel platform. In practice they can be treated as one platform, but we should confirm which one the phone reports (see section 8).

**Open question to verify:** the Samsung kernel source contains two configurations for this phone family, `pxa986_golden_rev02_defconfig` (with NFC) and `pxa986_goldennf_rev02_defconfig` ("nf" = no NFC). The only `goldenvess3g` device tree uses the NFC config. If the GT-I8200 really has no NFC, the "nf" config is probably the right starting point. This has to be checked against the phone's own kernel config, not assumed.

---

## 3. What already exists (inventory)

I cloned and inspected every relevant public repository I could find. "Inspected" means I read the files. I did **not** build or run anything.

### 3.1 Sources specifically for GT-I8200 (`goldenvess3g`)

| Repository | Last change | What it really is | Usefulness |
|---|---|---|---|
| [Gabrius99/android_device_samsung_goldenvess3g](https://github.com/Gabrius99/android_device_samsung_goldenvess3g) | 2016-03 | Device tree "starting from lt02wifi base" (copied from the Galaxy Tab 3 7.0 tree). CyanogenMod-era config: camera stubbed out, pre-KitKat audio flags. | **Medium.** Good reference for partitions, boot layout, Wi-Fi/BT flags. Not an Android 7 tree. Some values are inherited from the tablet and unverified (for example it names `sd8777` Wi-Fi firmware, but the phone's files contain `sd8787`). |
| [Gabrius99/proprietary_vendor_samsung_goldenvess3g](https://github.com/Gabrius99/proprietary_vendor_samsung_goldenvess3g) | 2017-02 | ~1,100 files: what looks like a raw copy of a stock (and rooted: contains `bin/.ext/.su`) Android 4.2 `/system`. No build.prop, so the exact firmware version is unknown. | **Low–medium.** Shows which proprietary files exist (GPU, RIL, camera, audio). Should **not** be used as the source of blobs: provenance unknown and modified. Blobs should come from official GT-I8200 firmware or your own phone. |
| [Gabrius99/kernel_goldenvess3g](https://github.com/Gabrius99/kernel_goldenvess3g) | 2016-02 | Linux 3.4.5, single commit, no history. Has GPU (galcore), Marvell Wi-Fi, touchscreen drivers. Includes a modified config with "-Sirius" branding. | **Medium.** Provenance unclear. Differs from both the I8200N Samsung source and the zvihell tree. Needs to be compared against Samsung's official GT-I8200 release. |
| [llbranco/cm12_gt-i8200](https://github.com/llbranco/cm12_gt-i8200) | 2016-08 | "CyanogenMod 12 port for GT-I8200". | **None.** The repository contains only a README and license. No code. |

### 3.2 Sources for the GT-I8200N (`goldenve3g`), the sister variant

| Repository | Last change | Notes |
|---|---|---|
| [zvihell/android_device_goldenve3g](https://github.com/zvihell/android_device_goldenve3g) + [kernel](https://github.com/zvihell/android_kernel_samsung_goldenve3g) + [vendor](https://github.com/zvihell/android_vendor_goldenve3g) | 2020-03 | Most complete CyanogenMod-style set (device + kernel + 168 vendor files). Built from **I8200N** firmware (`goldenve3gxx ... I8200NXXUAOC1`). The kernel adds a `cyanogenmod_goldenve3g_defconfig`. No README, no stated Android version or status. |
| [MasterPlexus/kernel_i8200](https://github.com/MasterPlexus/kernel_i8200) | 2014-12 | Despite the name, its README says it is Samsung's **GT-I8200N_EUR_XX** kernel source. |
| [MasterPlexus/android_device_samsung_goldenve3g](https://github.com/MasterPlexus/android_device_samsung_goldenve3g), [dflow81/device_goldenve3g](https://github.com/dflow81/device_goldenve3g) | 2015–2016 | Early recovery / Android 4.2–4.4 attempts with a prebuilt kernel. Mostly TWRP recovery settings. |

These are useful for comparison. The I8200 and I8200N probably share most hardware, but their kernel configs differ at least for NFC, so they must not be treated as interchangeable.

### 3.3 Sister devices on the same chip (the most valuable references)

| Project | Device | Chip | Status |
|---|---|---|---|
| [jakaco/lineageos-14.1-goyawifi](https://github.com/jakaco/lineageos-14.1-goyawifi) | Galaxy Tab 3 Lite SM-T110 (Wi-Fi only) | PXA986, GC1000, Linux 3.4.5 | **LineageOS 14.1, published 2026-11-04.** README reports display, hardware composition, Wi-Fi, Bluetooth, audio, rear camera, video decode, GPS and rotation working on the author's tablet. SELinux disabled. Suspend and battery not validated. Cellular disabled (Wi-Fi tablet). Publishes source patches, a pinned manifest and build scripts, but **not** the vendor blobs. **Self-reported, one device, not independently verified.** |
| [misanthropy81/android_device_samsung_lt02wifi](https://github.com/misanthropy81/android_device_samsung_lt02wifi) (cm-14.1 branch) | Galaxy Tab 3 7.0 SM-T210 | PXA986 | 2021 work-in-progress cm-14.1 tree ("WORK IN PROGRESS"). Status unknown. |
| [T110-android](https://github.com/T110-android) org | SM-T110/T111 | PXA986 | CyanogenMod 11 trees and a Samsung kernel. |
| [Samsung-OSS-Kernels/android_kernel_samsung_pxa986](https://github.com/Samsung-OSS-Kernels/android_kernel_samsung_pxa986) | SM-T210 | PXA986 | Mirror of Samsung's KitKat kernel source. Possibly newer than the 4.2-era GT-I8200 kernel. |
| [Alexandre4119/android_device_samsung_baffinlite](https://github.com/Alexandre4119/android_device_samsung_baffinlite) | Galaxy Grand Neo GT-I9060 | PXA1088 (related, newer chip, same GPU) | Active 2026, cm-13.0 (Android 6). Shows phone-side (RIL) work on a related Marvell phone, status unverified. |
| [LineageOS/android_hardware_marvell_wlan](https://github.com/LineageOS/android_hardware_marvell_wlan), [..._bt](https://github.com/LineageOS/android_hardware_marvell_bt) | — | Marvell Wi-Fi/BT | Official LineageOS support code for Marvell Wi-Fi/Bluetooth (cm-13.0 branch). |

Earlier PXA986 tablet attempts at LineageOS 14 (2017) stalled. Per search-result summaries of XDA threads, developers blamed the lack of updated Marvell kernels and the proprietary hardware-composer (display) blob. The 2026 SM-T110 project says it got past that.

### 3.4 Official sources

- **Samsung Open Source Release Center** (opensource.samsung.com) should host the GPL kernel source for GT-I8200. I could not confirm a GT-I8200 (non-N) package from this environment. The I8200N release is confirmed through the MasterPlexus mirror.
- **Stock firmware:** the GT-I8200 only ever shipped Android 4.2.2. That firmware is the legal source of the proprietary files we would need.

---

## 4. Hardware, part by part

What the source code tells us is inside the phone (from the device trees, kernel configs and vendor file lists):

| Part | Component found in sources | Android 7 situation |
|---|---|---|
| CPU | ARM Cortex-A9, dual-core, ARMv7 + NEON | Fine. LineageOS 14.1 still supports 32-bit ARMv7. |
| Kernel | Samsung Linux 3.4.5 (2013) | Old but usable. The SM-T110 port uses the same base. SELinux, audit and cgroups are **off** in stock configs. Android 7 boots without them, but security is weak. |
| GPU | Vivante GC1000, kernel `galcore` driver, blobs `libEGL_MRVL.so`, `libGLESv2_MRVL.so`, `gralloc.mrvl.so`, `hwcomposer.mrvl.so` | Android 4.2 blobs. Need compatibility "shims" under Android 7. This is the classic blocker, apparently solved on SM-T110. |
| Display | `pxa168fb` framebuffer, 800×480 | Fine once the GPU stack works. |
| Touchscreen | Atmel mXT224S (`CONFIG_TOUCHSCREEN_MXT224S`) | Pure kernel driver. Low risk. |
| Wi-Fi / BT | Marvell SD8787 combo (`sd8787_uapsta.bin`, `MarvellWirelessDaemon`) | LineageOS has Marvell Wi-Fi/BT code. Low–medium risk. |
| Audio | Marvell 88PM805 codec, ALSA, `audio.primary.mrvl.so`, old "pre-KitKat" audio blob flags | Android 7 no longer supports pre-KitKat audio blobs directly. Needs a wrapper or an open replacement. Medium risk. |
| Camera | Samsung S5K4ECGX (5 MP rear) + front camera, `camera.mrvl.so`, `libcameraengine.so` | Old camera HAL. The CyanogenMod-era GT-I8200 tree simply disabled the camera (`USE_CAMERA_STUB := true`). Different sensor from SM-T110. Medium–high risk. |
| Modem / RIL | Marvell telephony (`libmarvell-ril.so`, `libsecril-client.so`, `tel_launch.sh`, `MODEM` and `NVM` partitions) | Android 4.2-era RIL, must be adapted to Android 7's RIL interface. No precedent on this chip family. **Highest risk.** |
| Storage | eMMC, partitions KERNEL, RECOVERY, SYSTEM (~1.5 GB), CACHE, USER, EFS, MODEM, NVM | Big enough for LineageOS 14.1 without Google apps. EFS holds the phone's IMEI and must be backed up and never overwritten. |

---

## 5. Main risks

1. **Phone functions (calls, SMS, data).** The modem software is a 2013 binary written for Android 4.2. Android 7 changed the interfaces it plugs into. The fix can range from "a small shim" to "impossible without source code". There is no public example on this chip to learn from. **This decides whether the result is a real phone or a Wi-Fi device.**
2. **Graphics blobs.** If the SM-T110 work doesn't carry over (for example if the phone's 4.2.2 blobs are older than the tablet's), a lot of effort goes into getting the GPU working at all.
3. **Source provenance.** The GT-I8200-specific repositories are small, old, partly copied from tablets, and of unclear origin. Every file we reuse needs checking.
4. **Unverified reference project.** The SM-T110 LineageOS 14.1 port was published on the same day as this report. It is a strong lead, not proof.
5. **Security.** Without SELinux and with a 2013 kernel and no security updates since 2019 (LineageOS 14.1 is end-of-life), the result should not be used for banking or sensitive data.
6. **Performance.** About 1 GB of RAM (reported spec, not verified here) and a 2013 GPU will make Android 7 noticeably slower than stock. Expect usable but not smooth.
7. **Bricking risk during testing.** Mistakes when flashing KERNEL or EFS can make a phone unusable or erase its IMEI. Testing should happen only on a phone you are willing to risk, after a full backup.

---

## 6. Proposed roadmap

Each phase ends with a **go / no-go check**. We only move on when the check passes. Nothing is flashed to any phone before Phase 4, and never to your phone without your explicit approval.

### Phase 0 — Lock down facts (no phone changes, ~1 week)
- Get the official **GT-I8200** (not I8200N) kernel source from Samsung's Open Source Release Center, record its checksum, and compare it with the Gabrius99 and I8200N kernels.
- Get official GT-I8200 stock firmware from a trustworthy source (or read files from your phone, read-only; see section 8). Record the exact firmware build and checksums.
- Confirm: NFC present or not, PXA986 vs PXA988, Wi-Fi chip, camera sensors, partition layout.
- **Gate:** official kernel source and firmware for exactly GT-I8200 are in hand and verified.

### Phase 1 — Study the sister-device port (~1–2 weeks, desk work only)
- Read the SM-T110 LineageOS 14.1 project's patches, manifest and kernel changes. List every patch and whether it is chip-generic (reusable) or tablet-specific.
- Compare the tablet's proprietary blob versions with the GT-I8200's (GPU, gralloc, hwcomposer, audio).
- **Gate:** a written list showing which problems are already solved for this chip and which remain.

### Phase 2 — Kernel (~2–4 weeks)
- Build the official GT-I8200 kernel as-is, to prove the build setup reproduces Samsung's kernel.
- Add what Android 7 needs (and what the SM-T110 port added), keeping GT-I8200 board files.
- **Gate:** kernel compiles cleanly. (Booting it requires Phase 4.)

### Phase 3 — Device tree, vendor files, first full build (~3–6 weeks)
- Create `android_device_samsung_goldenvess3g` for LineageOS 14.1, using Gabrius99's tree and the SM-T110 work as references only.
- Create a clean vendor tree extracted from verified GT-I8200 firmware.
- Sync LineageOS 14.1 source (roughly 60–100 GB of disk) and build. This needs a bigger build machine than this session may have.
- **Gate:** a complete build finishes, and its boot image and system image pass static checks (sizes fit partitions, correct device name assertions, EFS and MODEM never written).

### Phase 4 — Hardware bring-up (needs a test phone; duration open-ended)
Bring features up in this order: boot and adb → display/GPU → touch → Wi-Fi → audio → Bluetooth → sensors/GPS → camera → **SIM, calls, SMS, data**.
- Before any flash: full backup of EFS, MODEM, NVM and the stock KERNEL/SYSTEM partitions, and a known way back to stock firmware.
- **Gate (minimum "usable"):** boots reliably, display + touch + Wi-Fi + audio work.
- **Gate ("usable phone"):** calls, SMS and mobile data work on a real SIM.

### Phase 5 — Stabilise and document
- Suspend/resume, battery life, long-run stability, a feature status table backed by test notes.

**Rough total:** 3–6 months of part-time skilled work to reach the "minimum usable" gate. The telephony gate is open-ended and might not be reachable.

---

## 7. What I can do here, and what I can't

**I can do in this environment:** source research, comparing code and blobs, writing the device tree and kernel changes, and possibly building (if disk space allows; LineageOS 14.1 needs a lot).

**I can't do here:** run anything on a phone, confirm any feature works, or download from sites this environment blocks. XDA Developers forums (`xdaforums.com`) were unreachable from this environment. Where this report mentions XDA threads, the information comes from search-result summaries, not from reading the threads.

---

## 8. Decisions and information needed from you

1. **Phone details (look only, change nothing):** in *Settings → About device*, the exact **Model number**, **Baseband version** and **Build number** (for example `I8200XX...`). Also: does *Settings → More networks* (or similar) show an **NFC** option?
2. **Test phone:** you have asked me not to touch your phone, which I'll respect. Phase 4 needs a physical device. The options are (a) later, with your explicit approval and a full backup, use your phone as the test phone; (b) buy a second, cheap GT-I8200 for testing (exactly GT-I8200, not I8200N or I8190); or (c) stop after Phase 3 with a built but untested ROM.
3. **Is a "Wi-Fi only" result acceptable** if calls and data turn out to be impossible? This decides how much time Phase 4 is worth.
4. **Network access:** if you want me to read the XDA threads directly, `xdaforums.com` needs to be allowed in this environment's network settings.

---

## 9. Sources

Repositories inspected directly (cloned and read):
- https://github.com/Gabrius99/android_device_samsung_goldenvess3g
- https://github.com/Gabrius99/proprietary_vendor_samsung_goldenvess3g
- https://github.com/Gabrius99/kernel_goldenvess3g
- https://github.com/llbranco/cm12_gt-i8200
- https://github.com/zvihell/android_device_goldenve3g
- https://github.com/zvihell/android_kernel_samsung_goldenve3g
- https://github.com/zvihell/android_vendor_goldenve3g
- https://github.com/MasterPlexus/kernel_i8200
- https://github.com/MasterPlexus/android_device_samsung_goldenve3g
- https://github.com/dflow81/device_goldenve3g
- https://github.com/misanthropy81/android_device_samsung_lt02wifi
- https://github.com/jakaco/lineageos-14.1-goyawifi (README only)

Found via search, not inspected in depth:
- https://github.com/Samsung-OSS-Kernels/android_kernel_samsung_pxa986
- https://github.com/T110-android
- https://github.com/Alexandre4119/android_device_samsung_baffinlite
- https://github.com/LineageOS/android_hardware_marvell_wlan
- https://github.com/LineageOS/android_hardware_marvell_bt
- https://github.com/kumajaya/android_kernel_samsung_lt02
- https://wiki.lineageos.org/devices/lt02ltespr/ (note: this is a Qualcomm-based Tab 3 variant, not PXA986)

XDA threads (known only through search summaries; site unreachable from this environment):
- https://xdaforums.com/t/cm-rom-for-s-iii-mini-value-edition-gt-i8200.3432885/
- https://xdaforums.com/t/rom-7-1-2-lineageos-14-1-for-gt-i8190-gt-i9070-2017-06-09.3520752/
- https://xdaforums.com/t/lineageos-14-unofficial-sm-t110-sm-t111-sm-t113-sm-t210-sm-t211.3615919/
- https://xdaforums.com/t/closed-project-lineage-14-unofficial-t110.3604371/
