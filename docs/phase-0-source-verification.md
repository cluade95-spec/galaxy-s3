# Phase 0: Source Verification — GT-I8200 (`goldenvess3g`)

**Date:** 2026-11-05 · **Status:** Phase 0 partly complete. One blocker remains: Samsung's own servers can't be reached from the research environment.
**Rules followed:** nothing was flashed or written to any phone. No ROM was downloaded. No Android build was started. Everything below comes from reading public source code and metadata.

> **Update 2026-11-05 (Phase 2 preparation):** later evidence refines this document. A genuine Samsung GT-I8200 kernel image from March 2015 shows the stock kernel includes the NFC (PN547) driver and was built from the golden rev02 configuration; the kernel's machine name is "PXA988"; and the Koloses tree's "I8200XXUAOC1" label conflicts with its January 2016 compile date. Details and sources: [phase-2-preparation.md](phase-2-preparation.md).

## How to read this document

Each finding carries one of these labels:

| Label | Meaning |
|---|---|
| **VERIFIED** | I checked it directly (read the files, compared hashes, read commit data). Anyone can repeat the check with the commit IDs given. |
| **STRONG EVIDENCE** | Several independent pieces of evidence agree, but there is no first-hand confirmation from Samsung or the phone. |
| **CLAIMED** | Someone else states it, and I could not check it. |
| **UNKNOWN** | Not established. Needs more work. |

---

## 1. Summary in plain language

1. **Samsung's official download site could not be reached.** opensource.samsung.com, Samsung's firmware servers, and the usual firmware mirror sites are all blocked by this research environment's network policy (section 2.1). So I could **not** download Samsung's GT-I8200 kernel package directly, and I could **not** download stock firmware.
2. **The best substitute is a GitHub copy of what looks like Samsung's original GT-I8200 kernel package.** Repository `Koloses/kernel_i8200`, first commit `44afe4c`, is labelled "I8200XXUAOC1 kernel source". `I8200XXUAOC1` is a real GT-I8200 (non-N) firmware build. The commit contains leftover build files showing the kernel was compiled on a **Samsung engineer's desktop in Korea in January 2016**. That strongly suggests an unmodified Samsung package (**STRONG EVIDENCE**, not an official download). It is the **newest** of all the GT-I8200-family kernels found and includes 2014 security fixes the others lack.
3. **The Gabrius99 "goldenvess3g" kernel is not the GT-I8200 source.** It is a modified copy of an older **GT-I8200N** Samsung release, by way of MasterPlexus's tree (**VERIFIED** by file comparison, section 4). It should not be the project's base.
4. **The kernel labelled "GT-I8200N" by zvihell is almost the same as the GT-I8200 package.** Only 5 files differ (**VERIFIED**). Either Samsung used one kernel for both variants, or zvihell labelled it wrongly. Either way, the labels on these repositories can't be trusted without checking.
5. **NFC:** public spec sheets say only the **GT-I8200N** has NFC. But Samsung's GT-I8200 kernel package was built with NFC support **switched on**. So the stock GT-I8200 kernel probably contains an NFC driver even if the phone has no NFC chip. Whether your phone physically has the chip is **UNKNOWN** until checked on the phone.
6. **Graphics, audio, camera and sensor driver files are byte-identical** between the GT-I8200 and GT-I8200N dumps. Only the modem software (RIL) differs, and each RIL was built for its own codename (**VERIFIED** on the dumped files; the dumps' own origin is unverified).
7. **The SM-T110 LineageOS 14.1 project is real, small and partly useful, but it can't be rebuilt from what is published.** Its graphics compatibility patches are concrete and look reusable. Its build depends on unpublished local files, and its "pinned manifest" lists only 54 of the several hundred source projects a full build needs. Its hardware results are the owner's own report, with no logs (section 6).

**Bottom line for Phase 0:** we have a credible GT-I8200 kernel source and exact firmware build names. We do **not** yet have an official Samsung download or a checksum-verified stock firmware. Section 8 lists what is needed to close those gaps.

---

## 2. Task 1: Official Samsung kernel source for GT-I8200

### 2.1 Direct official source: BLOCKED (not found, not ruled out)

| Host | Purpose | Result |
|---|---|---|
| `opensource.samsung.com` | Samsung Open Source Release Center (official kernel packages) | **Blocked**: HTTP 403 on CONNECT from the environment proxy |
| `www.samsung.com`, `doc.samsungmobile.com` | Samsung support pages | Blocked |
| `cloud-neofussvr.samsungmobile.com`, `neofussvr.sslcs.cdngc.net`, `fota-cloud-dn.ospserver.net` | Samsung firmware servers (FUS / FOTA) | Blocked |
| `samfw.com`, `www.sammobile.com`, `samfrew.com` | Third-party firmware mirrors | Blocked |
| `archive.org`, `web.archive.org`, `xdaforums.com` | Archives, forums | Blocked |

**What exactly is missing:** a copy of Samsung's official `GT-I8200_*_Kernel.zip` (or similar) downloaded from opensource.samsung.com, with its file name, release date and SHA-256. Until that exists, the GitHub copy in 2.2 can't be confirmed byte-for-byte against Samsung's original.

**How to unblock it:** allow `opensource.samsung.com` in this environment's network settings (Environment settings → Network access → Allowed domains). See https://code.claude.com/docs/en/cloud-environments#network-access. Alternatively, you could download the package yourself on a normal computer and add it to the repository.

### 2.2 Best available substitute: `Koloses/kernel_i8200` @ `44afe4c`

| Item | Value |
|---|---|
| URL | https://github.com/Koloses/kernel_i8200 |
| Import commit | `44afe4cf6023bf39c18bad72185003a40915fad2` ("Initial push of I8200XXUAOC1 kernel source", Koloses, 2016-03-05) |
| Import tree hash | `0eebf6f928a5cc5f58c4c93a0ca67d16a620e0cd` (40,994 files) |
| Repo HEAD | `039bfcd33dee57c14eb22836e5bede66641a1aee` (2016-03-06). 113 community patches on top (BFQ, F2FS, exFAT and so on). **Not** for use as a base. Only the import commit matters. |
| Kernel version | Linux 3.4.5 (**VERIFIED**, `Makefile`) |
| Board | `CONFIG_MACH_GOLDEN`, "Samsung's PXA986 GOLDEN Development Board", which `select CPU_PXA988` (**VERIFIED**, `arch/arm/mach-mmp/Kconfig`). So "PXA986" is the board/SoC marking and "PXA988" is the kernel platform family. |
| Configs included | `pxa986_golden_rev00/rev02_defconfig`, `pxa986_goldennf_rev00/rev02_defconfig`, plus about 146 other Marvell/Samsung board configs |

**Why it is probably Samsung's original package (STRONG EVIDENCE):**

- The import contains generated build files that Samsung's packages often ship by accident (`include/generated/compile.h`, `autoconf.h`, host tools under `scripts/`). `compile.h` says:
  ```
  UTS_VERSION "#1 SMP PREEMPT Wed Jan 13 17:18:42 KST 2016"
  LINUX_COMPILE_BY "kihyuk"
  LINUX_COMPILE_HOST "kihyuk-Samsung-DeskTop-System"
  LINUX_COMPILER "gcc version 4.6.x-google 20120106 (prerelease) (GCC)"
  ```
  That is a Korean-timezone build on a Samsung desktop, using the Android 4.2-era Google GCC 4.6. That points to Samsung's build, not a hobbyist's.
- The `Makefile` keeps the upstream name `Saber-toothed Squirrel` and Samsung's default `CROSS_COMPILE ?= /opt/toolchains/arm-eabi-4.6/bin/arm-eabi-`. There are no community edits.
- `I8200XXUAOC1` is a real GT-I8200 (non-N) firmware PDA version (section 3).

**Caveats:**
- There is no README_Kernel.txt from Samsung in this import, so the package name isn't stated inside it.
- The compile date (2016-01-13) is about 10 months after the build date implied by `UAOC1` (March 2015). Samsung often rebuilds when it publishes source, so this is plausible but unconfirmed.
- The import was compiled with **`pxa986_golden_rev02_defconfig`** (the NFC-enabled config). `autoconf.h` has `CONFIG_NFC=1`, `CONFIG_NFC_PN547=1`, `CONFIG_SEC_PM=1`. See section 5.

`astrit1/kernel_samsung_i8200` (https://github.com/astrit1/kernel_samsung_i8200, import `a0747700e2eee727668420607fcd08ecf10e2d4c`, 2017) is **the same source** with the 150 defconfigs stripped (all 40,844 common files identical, **VERIFIED**). It is independent confirmation that the same package circulated as "i8200" source. Its author kept only `pxa986_goldennf_rev02_defconfig`, the no-NFC config.

---

## 3. Task 2: GT-I8200 stock firmware identity

### 3.1 Device codename mapping (STRONG EVIDENCE)

| Model | Codename | Source |
|---|---|---|
| GT-I8200 | `goldenvess3g` | `liuzho/ADN` `names/goldenvess3g/gt-i8200.json` (Google Play device-list derived) |
| GT-I8200Q | `goldenvess3g` | same, `gt-i8200q.json` |
| GT-I8200N | `goldenve3g` | same, `names/goldenve3g/gt-i8200n.json` |
| GT-I8200L | `goldenve3g` | same, `gt-i8200l.json` |

Independent confirmation: the proprietary `libmarvell-ril.so` in the Gabrius99 dump contains the build path `out/target/product/goldenvess3g/...`, and the zvihell (I8200N) one contains `out/target/product/goldenve3g/...` (**VERIFIED** by `strings`). Each RIL binary was built for its own codename.

Note: **GT-I8200Q shares our codename** and is probably the closest sibling. GT-I8200L shares the I8200N codename.

### 3.2 Latest official firmware builds for GT-I8200 (non-N)

Source: `JeyKul/fwcheck2` (https://github.com/JeyKul/fwcheck2), a bot that records Samsung's FOTA "latest version" answer per region. Snapshot commit `03c0b40755534e68e6da9a0f2d2be28a0ae66fc9` (2026-11-05). Format: PDA / CSC / baseband. **CLAIMED** by that bot. I could not query Samsung's servers myself.

| Region (CSC) | PDA (system build) | CSC | Baseband |
|---|---|---|---|
| EUR | I8200XXUAOA2 | I8200EURAOB1 | I8200XXUAOA2 |
| ROM | I8200XXUAOA2 | I8200OXXAOB2 | I8200XXUAOA2 |
| CAC, SEK | I8200XXUAOB2 | I8200OXEAOB2 | I8200XXUAOA2 |
| ACR, AFG, PAK, XFE | **I8200XXUAOC1** | I8200OJVAOC2 | I8200XXUAOC1 |
| ATO | **I8200XXUAOC1** | I8200OXAAOC1 | I8200XXUAOC1 |
| BGL | I8200XXUAPB1 | I8200OXXAPA1 | I8200XXUAPA1 |
| SEE | I8200XXUAPB1 | I8200OXXAPC1 | I8200XXUAPC1 |
| VVT | I8200XXUAPB1 | I8200VVTAPB1 | I8200XXUAPA1 |
| AFR, BTC, EGY, KSA, MID, THR, TUN, XFA … | I8200XXUANI3 | I8200OJVANI2 | I8200XXUANI3 |
| COA, PHE | I8200XXUANJ3 | I8200OXXANI1 | I8200XXUANJ3 |
| XEO | I8200XXUANI3 | I8200XEOANH1 | I8200XXUANI3 |

How to read these version strings: `I8200` = model, `XX` = region group, `U` = update, `A` = bootloader revision, then year letter (`N`=2014, `O`=2015, `P`=2016), month letter (`A`=Jan … `L`=Dec), and build number. So **I8200XXUAPB1 (February 2016)** is the newest GT-I8200 build, and **I8200XXUAOC1 (March 2015)** matches the kernel source in 2.2. All GT-I8200 firmware is Android 4.2.2.

### 3.3 What is NOT verified

- **No firmware file was downloaded** (Samsung servers and mirrors are blocked, and you asked me not to download unverified ROMs). So there are no firmware checksums, no `build.prop`, and no extracted stock kernel config yet.
- The **Gabrius99 vendor dump** (`61139fc67f9184c154926175fdee933fa40b2712`) is from a `goldenvess3g` firmware (RIL build path, above), but it has no `build.prop`, so the exact firmware version is unknown. It also contains root files (`bin/.ext/.su`). It is a reference only and **not** a source of blobs for the project.

### 3.4 Shared vs variant-specific proprietary files (VERIFIED on the dumps)

SHA-256 comparison, Gabrius99 (`goldenvess3g`) dump vs zvihell (`goldenve3g`, I8200NXXUAOC1) vendor tree:

| File | Same in both? |
|---|---|
| `lib/egl/libEGL_MRVL.so`, `libGLESv2_MRVL.so` (GPU) | identical |
| `lib/hw/gralloc.mrvl.so`, `hwcomposer.mrvl.so` (display) | identical |
| `lib/hw/audio.primary.mrvl.so` | identical |
| `lib/hw/camera.mrvl.so` | identical |
| `lib/hw/sensors.mrvl.so` | identical |
| `lib/libril.so`, `lib/libsecril-client.so` | identical |
| **`lib/libmarvell-ril.so`** (modem interface) | **different**, built per codename |

This suggests that I8200 and I8200N share the graphics, audio, camera and sensor stack, and differ in the radio software. It is useful but rests on two community dumps of unverified origin.

---

## 4. Task 3: Kernel comparison

Method: list every file in each tree with its git blob hash (a content fingerprint) and compare. No blobs were trusted by name alone. Trees compared:

| Short name | Repository @ commit | Label given by its author | Tree hash |
|---|---|---|---|
| **KOL** | Koloses/kernel_i8200 @ `44afe4c` (import) | "I8200XXUAOC1 kernel source" | `0eebf6f9…` |
| AST | astrit1/kernel_samsung_i8200 @ `a074770` (import) | "Custom Kernel for S3 Mini I8200" | `af8fcfb8…` |
| GAB | Gabrius99/kernel_goldenvess3g @ `fb10380` | "Kernel sources for S3 Mini VE i8200x" | `a2c18d40…` |
| MPN | MasterPlexus/kernel_i8200 @ `f7d13ea` | README: "KERNEL 3.4.5 FOR GT-I8200N_EUR_XX" | `44101843…` |
| ZVI | zvihell/android_kernel_samsung_goldenve3g @ `a74bf17` | "Android kernel for GT-I8200N" | `8f0906ac…` |
| GOYA | T110-android/samsung_kernel_goya @ `562ba82` | Samsung SM-T110 source | `207719d8…` |
| T110K | T110-pmOS/linux_kernel_pxa988 @ `fb2f8b6` | Kernel used by the SM-T110 LineageOS port | `fa0eb07d…` |

| Comparison | Identical files | Different | Only in first | Only in second | Meaning |
|---|---|---|---|---|---|
| KOL vs AST | 40,844 | 0 | 150 | 0 | Same source; AST removed configs |
| KOL vs ZVI | 40,989 | **5** | 0 | 1 | **Practically the same package** (ZVI only adds a CM config and 4 build tweaks) |
| KOL vs MPN | 39,866 | 79 | 1,049 | 30 | Different Samsung release |
| KOL vs GAB | 39,837 | 76 | 1,081 | 3 | Different |
| GAB vs MPN | 39,843 | 70 | 3 | 62 | GAB derives from MPN (see below) |
| KOL vs GOYA | 39,843 | 99 | 1,052 | 31 | Sister tablet, same platform code |
| T110K vs KOL | 39,883 | 165 | 173 | 946 | SM-T110 port kernel is also close |

### 4.1 Gabrius99's kernel comes from the I8200N tree (VERIFIED)

- GAB and MPN both have the `Makefile` line `NAME = Baroni_level1`. That is **not** a Samsung or upstream name (upstream 3.4 is `Saber-toothed Squirrel`, as in KOL). It is MasterPlexus's custom edit.
- The 62 files "only in MPN" are other boards (baffin, cs02, degas, goya, lt02), MasterPlexus's extra CPU governors and exFAT, and build scripts. Gabrius99 removed them.
- Conclusion: **Gabrius99's "goldenvess3g" kernel is MasterPlexus's modified GT-I8200N_EUR kernel, trimmed and tweaked.** It is not Samsung's GT-I8200 source.

### 4.2 KOL is the newest release (VERIFIED)

| Security fix | KOL | MPN (I8200N) | GAB |
|---|---|---|---|
| CVE-2014-3153 "futex" root exploit (Towelroot): `if (uaddr1 == uaddr2)` check in `kernel/futex.c` | **present** | missing | missing |
| CVE-2014-2851 ping socket refcount: `put_group_info()` in `net/ipv4/ping.c` | **present** | missing | missing |

The 79 files that differ between KOL and MPN also include the GPU driver (`galcore`), Wi-Fi (`sd8787`), modem drivers (`marvell-telephony`), camera sensors (`s5k4ecgx_jcam.c`, `sr200pc20m.c`), touchscreen firmware (`mxt224s.fw.ihex`) and charger/PMIC drivers. So MPN/GAB are an earlier (2013/early-2014) Samsung drop, and KOL is a 2015/2016 drop.

### 4.3 Decision

- **Primary kernel base (provisional): KOL import `44afe4c`.** Provisional until it is matched against Samsung's official package (section 2.1) or against the stock kernel extracted from verified firmware.
- **Not to be used as a base:** GAB (I8200N-derived, older, modified) and MPN (I8200N, older).
- **Reference only:** ZVI (same content as KOL, labelled I8200N), T110K (shows what the SM-T110 port changed).

---

## 5. Task 4: NFC configuration and hardware differences

### 5.1 What the kernel source says (VERIFIED)

`pxa986_golden_rev02_defconfig` vs `pxa986_goldennf_rev02_defconfig` in KOL. These are the **only** differences:

```
golden_rev02                  goldennf_rev02
CONFIG_SEC_PM=y               # CONFIG_SEC_PM is not set
CONFIG_SEC_PM_DEBUG=y
CONFIG_NFC=y                  # CONFIG_NFC=y        (disabled)
CONFIG_NFC_PN547=y            # CONFIG_NFC_PN547=y  (disabled)
# CONFIG_SWITCH_88PM822_HS... #CONFIG_SWITCH_88PM822_HS=y (comment only)
```

`rev00` vs `rev02` differ in battery/charger chips (RT5033 on rev00; 88PM822 fuel gauge, RT9455 charger and RT8547 flash LED on rev02). So `rev` is a **board hardware revision** and `nf` means **no NFC**.

`arch/arm/mach-mmp/board-golden.c` wraps all NFC code (NXP PN547 chip on I²C-GPIO 33/34, IRQ GPIO 91, enable GPIO 126, firmware GPIO 127) in `#if defined(CONFIG_NFC_PN547)`. There is **no runtime check** that tells NFC and non-NFC boards apart. The choice is made only at compile time.

### 5.2 What Samsung actually built (VERIFIED for the KOL package)

`include/generated/autoconf.h` in the KOL import has `CONFIG_NFC=1`, `CONFIG_NFC_PN547=1`, `CONFIG_SEC_PM=1`. That means the package was built with **`golden_rev02` (with NFC)**, the same config named in Samsung's I8200N README.

### 5.3 What spec sheets say (CLAIMED)

GSMArena and DeviceBeast (via search snippets) list NFC on the **GT-I8200N only**. One other site (GSMFind) doesn't distinguish variants.

### 5.4 Interpretation

- **Most likely** (STRONG EVIDENCE, not proof): Samsung shipped one kernel config, with NFC, for the whole `golden` family. On a GT-I8200 without the NFC chip, the PN547 driver would just find nothing. The `goldennf` config exists but may not have been used for any shipped firmware.
- **For our build:** start from `golden_rev02` to match stock behaviour. Plan to switch to `goldennf_rev02` once we confirm the phone has no NFC chip, which removes a driver for missing hardware.
- **Also unknown:** whether a given GT-I8200 is board `rev00` or `rev02`. These have different charger/fuel-gauge chips, which matters for battery and charging. The kernel reads `board_id`/`system_rev` from the bootloader at runtime (`board-golden.c` line 160), so this has to be read from the phone.

### 5.5 Known I8200 vs I8200N differences

| Area | Difference | Status |
|---|---|---|
| NFC | I8200N has NXP PN547. I8200 probably none. | CLAIMED (spec sheets); kernel shows PN547 support only |
| Modem software | `libmarvell-ril.so` differs, built per codename | VERIFIED on dumps |
| GPU, display, audio, camera, sensor blobs | Identical binaries | VERIFIED on dumps |
| Kernel source | Same Samsung package circulates for both (KOL = ZVI) | VERIFIED |
| Partition sizes | Gabrius99 tree: boot 12 MiB, system 1,507,852,288. zvihell/MasterPlexus: boot 16 MiB, system 1,594,884,096 | UNKNOWN which is right for GT-I8200. Gabrius99 values may be copied from a tablet. Must be read from the phone's PIT/partition table. |

---

## 6. Task 5: SM-T110 LineageOS 14.1 repository audit

**Repository:** https://github.com/jakaco/lineageos-14.1-goyawifi
**Commit audited:** `df7ed54649066b0304b324359d3631037e6664c1` (tree `cd2fae8c…`). Tags: `lineage-14.1-goyawifi-2026.11.04-r1` → `26e600ae…`, `-r2` → `df7ed546…`
**History:** 6 commits, all by "Jakaco" on 2026-11-04 between 15:37 and 16:39 (+0100). The whole history is one afternoon, and there is no development history before it.
**Release binaries:** not downloaded (by your rule). GitHub release pages returned HTTP 403 through the proxy, so the assets' existence and size are unverified. The repo lists their SHA-256: r1 `bbb5be4a…10ff`, r2 `df213221…cfdf`.

### 6.1 What is actually in the repository (VERIFIED)

| Part | Content |
|---|---|
| Kernel | Points to `T110-pmOS/linux_kernel_pxa988` @ `fb2f8b6cd86864c0fcac790e97a372b1772003c7` (**exists**: "Delete strace files", cheadrian, 2022-06-24, on `master`; a postmarketOS project), plus 4 patches: initrd length, native LCD panel/framebuffer, `-fno-pic` for Wi-Fi/netfilter modules, and a UID-routing backport that Android 7 networking needs. A full `kernel.config` is included. |
| Android patches (8) | `bionic` (lets the stock Vivante `libGAL.so`, which has text relocations, load). `frameworks/native` (legacy EGL buffer-queue workaround, a "retire" thread to replace the missing display fence, HWC stride option, xattr workaround). `hardware/libhardware` (**HWC 1.2 layer struct padded to 100 bytes to match the stock Marvell binary ABI**). `system/core` (init can run **without SELinux**). `frameworks/base` (hwui/SystemServer tweaks). Camera service startup, netd diagnostics, CM display calibration. |
| Device config | `device/samsung/goyawifi` (product makefile, fstab, overlay), `goyawifi-init` (bring-up probes, binder shim), `goyawifi-camera` (a **custom camera HAL**, `camera-hal.cpp`, plus a custom camera app). |
| Build scripts | Staged scripts (`build-nougat-kernel/core/graphics/services/art.sh`), plus `assemble-full-lineage.py` and `build-twrp-zip.py`. |

### 6.2 Can it be rebuilt from what is published? **No** (VERIFIED)

1. **The manifest is incomplete.** `sources/lineage-14.1-resolved-manifest.xml` lists **54 projects** (bionic, build, system/core, frameworks/native, toolchains and so on). A full LineageOS 14.1 tree has several hundred, including `frameworks/base`, `frameworks/av` and all apps. Yet `assemble-full-lineage.py` requires a full system image containing Trebuchet, Settings, SystemUI and others. The revisions for most of the tree are **not pinned anywhere** in the repository (`camera-source-pins.json` and `wifi-source-pins.json` pin a few more).
2. **`device/samsung/goyawifi/BoardConfig.mk` includes `device/samsung/goyawifi-framework/BoardConfig.mk`, which is not in the repository.**
3. **The final system image is assembled from unpublished local folders** (`GOYAWIFI_WORK_DIR`): `graphics-vendor-runtime-manifest.json`, `wifi-/audio-/bluetooth-/camera-/gps-/sensors-runtime/`, a prebuilt `galcore.ko`, `libshim_goyawifi_binder.so`, `healthd`, and a "known-good" `boot-internal.img` template whose ramdisk is reused. None of these are in the repo. Some are Samsung proprietary files (legitimately excluded), but others are built or hand-made pieces.
4. Scripts hard-code the author's host paths (`/mnt/j/Codex-builds/android7-goyawifi/...`, a chroot named `xenial`). BUILD.md says they "may need host-path edits".
5. The boot flow is non-standard: a custom `init.framework.rc` and `sbin/internal-setup.sh` that use busybox to fix permissions at boot.

### 6.3 Reported hardware support (CLAIMED, owner-only)

From `HARDWARE_STATUS.md`: boot/UI, display + hardware composition, Wi-Fi, audio (speaker, headset, mic), Bluetooth (file transfer, A2DP), rear camera (photo, video), 720p hardware video decode, GPS (3 satellites), accelerometer rotation. The evidence column says "owner-visible use", "owner confirmation", "no coordinate log". No logs, screenshots or third-party reports are included. Not validated: suspend/resume, battery, long-run stability. SELinux is disabled (`ro.build.selinux=0`). Cellular is removed.

### 6.4 What is reusable for GT-I8200

| Item | Reuse value | Why |
|---|---|---|
| HWC 1.2 100-byte layer ABI patch, legacy EGL queue patch, Vivante textrel linker exception, framebuffer retire thread | **High (if the blobs match)** | Our GPU/HWC blobs are also Android 4.2.2 Marvell builds. Whether they are the **same versions** as the SM-T110's is UNKNOWN, because the SM-T110 blobs aren't published. To check: compare against SM-T110 stock firmware. |
| Kernel UID-routing backport, `-fno-pic` module fix, initrd fix | **High** | Same 3.4.5 Marvell kernel family; generic Android 7 requirements |
| No-SELinux init patch | Usable for bring-up only | Security cost. Ideally replaced later. |
| Custom camera HAL | Low–medium | Different camera sensor (S5K4ECGX on GT-I8200). The approach can be studied. |
| Build/assembly scripts | Low | Unreproducible; host-specific |
| Anything telephony | **None** | The tablet build removes the phone stack |

---

## 7. Task 6: Reference table (URLs, commits, checksums)

| Item | URL | Commit / ID | Checksum or hash | Status |
|---|---|---|---|---|
| GT-I8200 kernel (best available) | github.com/Koloses/kernel_i8200 | `44afe4cf6023bf39c18bad72185003a40915fad2` | git tree `0eebf6f928a5cc5f58c4c93a0ca67d16a620e0cd` | STRONG EVIDENCE it is Samsung's package |
| Same kernel, configs stripped | github.com/astrit1/kernel_samsung_i8200 | `a0747700e2eee727668420607fcd08ecf10e2d4c` | tree `af8fcfb81a7985f48a7e687cf79b0de4778c170f` | VERIFIED identical common files |
| GT-I8200N kernel (Samsung EUR) | github.com/MasterPlexus/kernel_i8200 | `f7d13ea4bc092ce89b1af8c0ebdb6345eb7ec4bf` | tree `441018430091c0040268a16b7611353ab4b11446` | VERIFIED I8200N per its README |
| Gabrius99 kernel | github.com/Gabrius99/kernel_goldenvess3g | `fb103805b2f7f2e31c8638a290d8ee2a9990e04e` | tree `a2c18d40f914b67bde0a81a7fdeeeb1116e70221` | VERIFIED derived from MPN |
| zvihell kernel | github.com/zvihell/android_kernel_samsung_goldenve3g | `a74bf17260a08672aab78a3586f4b90fd69f57c5` | tree `8f0906ac0189190e811b290d2af606270c03d807` | VERIFIED ≈ KOL |
| SM-T110 Samsung kernel | github.com/T110-android/samsung_kernel_goya | `562ba82bb07bde98d1876eb1f8fec8de019cb301` | tree `207719d816bc84a4b372da41eaed430c801a915c` | reference |
| SM-T110 port kernel | github.com/T110-pmOS/linux_kernel_pxa988 | `fb2f8b6cd86864c0fcac790e97a372b1772003c7` | tree `fa0eb07d375917720a6259b37bf1a08f67406453` | VERIFIED exists |
| SM-T110 LineageOS 14.1 port | github.com/jakaco/lineageos-14.1-goyawifi | `df7ed54649066b0304b324359d3631037e6664c1` | tree `cd2fae8c6d585156a7c01d25b1a54f6ec33d7090` | Audited; not reproducible |
| Gabrius99 device tree | github.com/Gabrius99/android_device_samsung_goldenvess3g | `470dfde15c790b04389ae57f8683b929ccacb808` | — | reference |
| Gabrius99 vendor dump (goldenvess3g) | github.com/Gabrius99/proprietary_vendor_samsung_goldenvess3g | `61139fc67f9184c154926175fdee933fa40b2712` | — | reference only; rooted, version unknown |
| zvihell device / vendor (I8200N) | github.com/zvihell/android_device_goldenve3g, …/android_vendor_goldenve3g | `2adaa3cb…`, `21fb3b5e…` | — | reference |
| Firmware version list | github.com/JeyKul/fwcheck2 | `03c0b40755534e68e6da9a0f2d2be28a0ae66fc9` | — | CLAIMED (bot output) |
| Codename list | github.com/liuzho/ADN | `b665356a43168adaa6ec632c58d39ec201f969bf` | — | STRONG EVIDENCE |
| Samsung official kernel package | opensource.samsung.com | — | — | **BLOCKED** |
| Stock firmware file | Samsung FUS / mirrors | — | — | **BLOCKED / not downloaded** |

Blob SHA-256 prefixes for the shared proprietary files are in section 3.4. Full hashes can be regenerated from the commits above with `sha256sum`.

---

## 8. What is still needed to finish Phase 0

| # | Gap | How to close it | Who |
|---|---|---|---|
| 1 | Official Samsung GT-I8200 kernel package + SHA-256 | Allow `opensource.samsung.com` in the environment network settings, **or** you download it on a normal computer (search "GT-I8200" on opensource.samsung.com) and add it to the repo | You (settings or download), then me (compare against KOL `44afe4c`) |
| 2 | Verified stock firmware (preferably **I8200XXUAOC1** to match the kernel, or the newest for your region) + checksums | Allow Samsung firmware servers, **or** you download official firmware with a reputable tool such as Samloader/Bifrost, which pull from Samsung's own servers | You, then me (extract and hash, read-only) |
| 3 | Your phone's identity | Settings → About device: **Model number, Baseband version, Build number**. Look only, change nothing. | You |
| 4 | NFC chip present? | Settings → More networks (or Connections): is there an **NFC** toggle? | You |
| 5 | Board revision and partition sizes | Needs either the stock firmware's PIT file (from item 2) or a read-only `adb shell cat /proc/partitions` with USB debugging on. That reads only and writes nothing, but only with your OK. | Later, with approval |
| 6 | SM-T110 blob versions vs GT-I8200 blobs | Needs SM-T110 stock firmware (same download route as item 2) | Later |

Phase 1 (studying the SM-T110 patches in depth) can start now in parallel. It doesn't depend on these gaps.
