# Phase 2: experimental computer-only build of the Koloses GT-I8200 kernel

**Date:** 2026-11-05 · **Approved scope:** a computer-only experimental build of `Koloses/kernel_i8200`.
**Boundaries followed:** no connection to any phone; nothing flashed, unlocked, rebooted or written to a phone; no recovery or Android ROM built; the original source was not modified (every change to the experimental copy is listed in section 4); nothing installed system-wide. Binary build outputs (kernel images, modules) stay outside the repository.

## How to read this document

| Label | Meaning |
|---|---|
| **VERIFIED** | Measured by me in this session; the commands and logs are in this repository. |
| **CLAIMED** | Stated by a third party; I could not check it against Samsung. |
| **UNKNOWN** | Not established. |

---

## 1. Result in plain language

1. **The build succeeded.** Using the original Android-era Samsung toolchain (not a modern compiler), the Koloses source compiles cleanly into a normal ARM kernel image (`zImage`, 3.9 MB) in about 80 seconds, plus 20 add-on driver modules, including the GPU (`galcore`), Wi-Fi and modem ones.
2. **The Koloses source reproduces the code of a genuine Samsung GT-I8200 kernel.** When built with the settings Samsung used for its release kernels, the machine code (all 5,144,576 bytes of it) is **identical, byte for byte**, to the genuine March 2015 GT-I8200 kernel found in a community device tree. All 41,847 symbols have identical names, sizes and addresses.
3. **The image is not bit-for-bit identical, and I do not claim it is.** Out of 8,455,412 bytes, the only differences are the folder path of the build machine, which the kernel stores in 722 compiler-generated source-file names (I replaced it with text of the same length to compare), a 20-byte build fingerprint, and 6 bytes of timestamps. Section 6 shows this in detail.
4. **What this tells us about trust:** the Koloses source has been shown to produce the same compiled code as a real Samsung GT-I8200 release. A copy of the source that had been altered in any compiled file would have produced a difference. This is strong support for using it as a base. It is still not a comparison with Samsung's own download (which I can't reach), it covers only the code that is actually compiled for this phone, and it covers one firmware version (I8200XXUAOC1, March 2015).
5. **One important practical finding for a custom ROM:** Samsung's release kernel has extra "production" restrictions that block some root and user-ID changes (`sec_restrict_uid` and similar). They are **off** in the plain default configuration and on in Samsung's shipped one. A LineageOS kernel will probably want them off. That is the configuration I call Build A below.

Nothing in this document says the kernel works on a phone. It was never run on one.

---

## 2. Environment inspected before building

(Full record: `docs/build-logs/environment.txt`.)

| Item | Found | Verdict |
|---|---|---|
| Host | Ubuntu 24.04.5, Linux 6.18, x86-64, 4 CPUs, 15 GiB RAM, 19–29 GB free disk | Sufficient (a build uses about 1.5 GB per output folder) |
| System compiler | GCC 13.3.0, GNU make 4.3, perl 5.38.2, python 3.13, bison 3.8.2, binutils 2.42 | Too new for 2013-era kernel code; **not used for the kernel**. Used only for small helper programs that run on the build computer (see 5.2). |
| ARM cross compiler on the host | none installed | Missing, so I fetched the original one (below) into a scratch folder |
| `flex`, `lzop`, `cpio` | not installed | Not needed for this kernel (gzip-compressed; parser files are pre-generated) |
| Network | GitHub and `android.googlesource.com` reachable | Used for the source and the toolchain |
| Privileges | read/write only in the project and scratch folders; nothing installed system-wide | Respected |

### The toolchain: the original, not a substitute

| Evidence | Source |
|---|---|
| Samsung's build instructions say to use the arm-eabi-4.6 toolchain from the Android source code (`CROSS_COMPILE ?= /opt/toolchains/arm-eabi-4.6/bin/arm-eabi-` in the kernel `Makefile`) | VERIFIED, `Makefile` in the tree |
| The genuine GT-I8200 kernel's version banner names its compiler: `gcc version 4.6.x-google 20120106 (prerelease) (GCC)` | VERIFIED, banner of the reference image |
| The official Android project's `arm-eabi-4.6` prebuilt reports exactly that compiler | VERIFIED: `arm-eabi-gcc (GCC) 4.6.x-google 20120106 (prerelease)`, GNU ld/as 2.21 |

I used **AOSP `platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6`, branch `jb-mr1-release` (Android 4.2), commit `d73a051b1fd1d98f5c2463354fb67898f0090bdb`** (24 Apr 2012, "Upgrade to host 64bit arm-eabi toolchain"), from `android.googlesource.com`. It is a 64-bit program and runs on this host without installing anything. SHA-256 of `arm-eabi-gcc` is `07c0e03f…3e7c`. (All four tool hashes are in the environment record.)

---

## 3. Target identified from the source and evidence

| Item | Value | Evidence |
|---|---|---|
| Source | `https://github.com/Koloses/kernel_i8200`, commit `44afe4cf6023bf39c18bad72185003a40915fad2` ("Initial push of I8200XXUAOC1 kernel source", 2016-03-05), tree `0eebf6f928a5cc5f58c4c93a0ca67d16a620e0cd`, 40,994 files | VERIFIED. I used the import commit, not the repository's latest commit (113 later community patches). |
| Kernel | Linux 3.4.5 | VERIFIED, `Makefile` |
| Architecture | 32-bit ARM, ARMv7-A (`-march=armv7-a`, EABI5, little-endian, ARM mode not Thumb, soft-float calling convention), 2 CPUs (`CONFIG_NR_CPUS=2`, SMP, preemptible, `HZ=128`) | VERIFIED, from the compile command and `readelf` |
| Board | `CONFIG_MACH_GOLDEN`, machine name "PXA988" (`MACHINE_START(GOLDEN, "PXA988")`), CPU `CONFIG_CPU_PXA988` | VERIFIED |
| Configuration file | `arch/arm/configs/pxa986_golden_rev02_defconfig` | See below |
| Compression | gzip (`CONFIG_KERNEL_GZIP`), optimisation for size (`-Os`) | VERIFIED |

### Why this configuration (and why there are two variants of it)

1. **Samsung's own leftover build output matches the plain defconfig exactly.** The Koloses tree still contains the file `include/generated/autoconf.h` from the Samsung engineer's own build. I generated that file from `pxa986_golden_rev02_defconfig` and compared: **all 860 `CONFIG_` definitions are identical, 0 differences** (VERIFIED). So the engineer's January 2016 development build used the plain defconfig. That is **Build A**.
2. **The genuine release kernel was built with five more options.** Samsung's kernel `Android.mk` (in the tree) turns on `CONFIG_SAMSUNG_PRODUCT_SHIP`, `CONFIG_SEC_RESTRICT_ROOTING`, `…_SETUID`, `…_FORK` and `…_ROOTING_LOG` for shipped ("USER") builds. The genuine image contains the code those options add: symbols `sec_restrict_uid` and `sec_check_execpath`, and the messages "Restricted changing UID" and "Restricted making process" (VERIFIED in the reference image). That is **Build B**, and **Build C** is Build B with the build labels matched (below).
3. Only these five options differ between A and B (`docs/build-logs/31-config-diff-A-vs-B.txt`).

I did **not** pick an arbitrary configuration: A is what the tree's own leftovers prove, and B/C is what Samsung's own build file and the genuine binary show.

---

## 4. Preserving the original source, and every change made

| Copy | What | State |
|---|---|---|
| `pristine/` | Fresh `git clone` of the repository at commit `44afe4c…` | **Never built in, never edited.** After all builds: `git status` empty, `HEAD` = `44afe4c…`, tree = `0eebf6f9…` (VERIFIED). |
| `experimental/` | Copy of `pristine/` used for builds A and B | Only change: 899 files deleted by Kbuild's own cleaner `make mrproper` (see below) |
| `kernelbuild/` | Copy of `experimental/` without the `.git` folder, at a path exactly 94 characters long, used for build C | No further change. A recursive comparison with `pristine/` found no difference other than the missing generated files. |

**The only change to the source copies: removal of 899 generated files.** The Koloses tree contains build leftovers from Samsung's earlier build (the generated headers under `include/config/`, `include/generated/`, `arch/arm/include/generated/`, `include/linux/version.h`, and 8 compiled helper programs plus 4 generated parser files under `scripts/`). Kbuild refuses to build into a separate output folder while these exist, so I ran the standard command `make ARCH=arm CROSS_COMPILE=… mrproper`. It deleted exactly those files and touched no real source file: `git status` of the copy shows 899 deletions and 0 modifications. The full list is `docs/build-logs/experimental-copy-deleted-files.txt`. (The 8 helper programs had been built with Ubuntu/Linaro GCC 4.6.3; they are rebuilt from source during the build.)

**No source file was edited to make it compile.**

---

## 5. Build attempts and results

### 5.1 Variants

| Variant | Configuration | Build labels | Purpose |
|---|---|---|---|
| **A** | `pxa986_golden_rev02_defconfig` only | neutral (`experimental@goldenvess3g-exp`, 2026-11-05) | Baseline: what Samsung's development build used. Likely the best base for a custom ROM (no root restrictions). |
| **B** | A + the five Samsung production options | neutral | Closest *configuration* to Samsung's shipped kernel |
| **C** | B | version label, user, host, build number and date set to the values seen in the genuine image's banner (`3.4.5-2825398`, `se.infra@SWDB2803`, `#2 … Wed Mar 18 09:23:47 KST 2015`), source path length equal to Samsung's | A **comparison build only**: removes label-only differences so that real code differences stand out. **It is not an official build and must never be presented as one.** |

### 5.2 What had to be accommodated, and why it does not touch the kernel code

| Problem | Cause | Handling | Source touched? |
|---|---|---|---|
| **First attempt failed** at `kernel/timeconst.h`: *"Can't use 'defined(@array)' (Maybe you should just omit the defined()?) at …/kernel/timeconst.pl line 373."* (`docs/build-logs/20-A-build-attempt1-FAILED-perl-5.38.log`) | The 2012 script uses a Perl construct that Perl 5.22 and later reject. The build host has Perl 5.38. | `make PERL=tools/kernel-build/perl-shim.sh`. For this one script, the shim applies the one-line upstream fix (`!defined(@val)` → `!@val`, identical meaning) to a temporary copy at run time and prints the difference to the log. Every other Perl call passes through untouched. | **No** |
| Host helper programs compile with modern GCC 13 | Kbuild builds a few small programs that run on the build computer (configuration reader, symbol tools) | Built with the system GCC 13 (`HOSTCC=gcc`); it produced warnings only. These programs never become part of the kernel. | No |
| Kernel version gets a `+` suffix in A and B | Kbuild appends `+` when `LOCALVERSION` is not set | Left as is in A and B (documented); C sets `LOCALVERSION` as Samsung's build file does | No |
| Samsung's kernel files give 572 compiler warning lines (C build) and a configuration warning ("ZRAM selects ZSMALLOC which has unmet direct dependencies (STAGING && X86)") | Old code, old config | Not hidden: all in the logs. No errors. | No |

I did **not** use a modern compiler for any kernel code, did not alter any compiler flag the kernel selects for itself, and did not substitute a configuration.

### 5.3 Results

All builds were run as `make -j4 O=<output dir> ARCH=arm CROSS_COMPILE=<toolchain>/bin/arm-eabi- HOSTCC=gcc PERL=<shim> [LOCALVERSION=…] zImage` from the source copy (exact commands in Appendix A). All wall-clock times were about 78 seconds.

| Run | Result | Log |
|---|---|---|
| A, attempt 1 (no shim) | **FAILED**, cause above | `20-A-build-attempt1-FAILED-perl-5.38.log` (complete) |
| A, attempt 2 (with shim) | **Succeeded** | `21-A-build-ok-defconfig-only.log` |
| B | **Succeeded** | `32-B-build-ok-ship-options.log` |
| C | **Succeeded** | `51-C-build-ok-metadata-matched.log` |
| C, kernel modules (`make modules`) | **Succeeded**: 20 `.ko` files, including `galcore.ko` (GPU), `mlan.ko` and `sd8xxx.ko` (Wi-Fi), `mbt8xxx.ko` (Bluetooth), the `msocketk`, `ccinetdev`, `cploaddev`, `seh`, `citty` and related modem-interface modules, `physrw`, `geu`. Module version tag `3.4.5-2825398 SMP preempt mod_unload ARMv7`. | `52-C-modules-ok.log` |
| Independent re-run of A, B and C with the project script, in a fresh folder | **Succeeded** (4 min 22 s total) | `60-reproduction-script-run.log` |

---

## 6. The output kernel image, and comparison with the genuine one

### 6.1 What was produced (Build C; A and B are alike in format)

| Property | Value |
|---|---|
| File | `arch/arm/boot/zImage`: "Linux kernel ARM boot executable zImage (little-endian)" |
| Size | 3,872,040 bytes (genuine image: 3,871,984) |
| Layout | decompressor stub of 16,439 bytes + one gzip stream (starts at offset `0x4037`, same as the genuine one) |
| Decompressed image | 8,455,412 bytes (same length as the genuine one) |
| `vmlinux` | ELF32 little-endian, machine ARM, EABI5, entry `0xc0108000`, with debug information, 102,085,450 bytes |
| Version banner (C) | `Linux version 3.4.5-2825398 (se.infra@SWDB2803) (gcc version 4.6.x-google 20120106 (prerelease) (GCC) ) #2 SMP PREEMPT Wed Mar 18 09:23:47 KST 2015`. **These labels were set by me for the comparison.** |
| Version banner (A) | `Linux version 3.4.5+ (experimental@goldenvess3g-exp) (gcc version 4.6.x-google 20120106 (prerelease) (GCC) ) #1 SMP PREEMPT Thu Nov 5 00:00:00 UTC 2026` |
| Compile flags (from `.cmd` files) | `-Os -marm -mabi=aapcs-linux -mno-thumb-interwork -march=armv7-a -msoft-float -funwind-tables -fomit-frame-pointer -fno-stack-protector -g` etc. |
| Embedded build details | 722 copies of the source folder path (compiler-generated source-file names used by the kernel's internal error reports), a GNU build fingerprint (20 bytes), a minimal embedded initramfs (it holds a `dev` folder entry) stamped with the build time |

SHA-256 values (path-specific, so they differ between runs) are in Appendix B. The images are not committed.

### 6.2 The reference image

The genuine image is the `kernel` file in `Koloses/device_i8200` (commit `3bcf4bbe54cb6e9be973fcd88084eb59ef458623`; SHA-256 `52795a2e64095cd525b27afdd56f4b601dfd8d9ba6e542088ef70c8bc2650860`). **It is a community-provided file; its origin is CLAIMED, not verified** (see `docs/phase-2-preparation.md`, section 2). Its identity as a Samsung GT-I8200 kernel rests on the evidence stated there: Samsung's build-farm user and host in the banner, the changelist number 2825398 matching firmware I8200XXUAOC1 in a third-party list, and the embedded workspace name `HUDSON_JELLYBEANPLUS_GOLDENVESS3G_EUR-XX_USER`.

### 6.3 Symbol-by-symbol comparison (tool: `kallsyms-finder`, then `tools/kernel-build/compare-symbols.py`)

| | Symbols (names) | Names only in genuine | Names only in mine | Comparable symbols with equal size | Symbols at identical address |
|---|---|---|---|---|---|
| Genuine | 41,847 | | | | |
| **A** (defconfig only) | 41,843 | 5 (`sec_restrict_uid`, `sec_check_execpath`, their export-table entries, one numbered label) | 2 numbered labels | 41,023 / 41,054 (99.924%) | 1,330 / 41,055 (3.24%) |
| **B** (+ production options) | 41,847 | **0** | **0** | 41,052 / 41,060 (99.981%) | 22,791 / 41,061 (55.51%) |
| **C** (+ matching labels) | 41,847 | **0** | **0** | **41,060 / 41,060 (100%)** | **41,061 / 41,061 (100%)** |

Reading it: A lacks exactly the Samsung production code, which is the proof that the genuine kernel was built with those options. B has the same inventory and almost the same sizes but different version-label text, which moves later data to other addresses. C has everything identical.

Logs: `40-compare-A-vs-stock.txt`, `41-compare-B-vs-stock.txt`, `42-compare-C-vs-stock.txt`.

### 6.4 Byte-level comparison of the decompressed images (Build C vs genuine)

| Region | Result |
|---|---|
| **Code (`.head.text` + `.text`, 5,144,576 bytes)** | **100.000% identical, 0 bytes differ** (raw, before any normalisation) |
| Whole image, raw | 65,728 of 8,455,412 bytes differ (0.78%) |
| Where the 65,728 differ | 678 groups of about 93 bytes each in the read-only text-string area, plus 4 small groups in data |
| Cause of the 678 groups | The 94-character folder path of Samsung's build machine (`/home/se.infra/jenkins1/workspace/HUDSON_JELLYBEANPLUS_GOLDENVESS3G_EUR-XX_USER/android/kernel`) is stored 722 times as compiler-generated source-file names, versus my build folder path. I deliberately built in a folder whose path has the same **length**, so nothing moves. |
| **After replacing only those path strings (722 replacements; the genuine image also has 722)** | **26 bytes differ out of 8,455,412**: 20 bytes are the GNU build fingerprint (a hash of the whole build, which cannot match), and 6 bytes are the timestamps of three folder entries in the embedded initramfs (genuine `0x5508C571`, mine `0x5508C593`; this is consistent with Samsung's tool having stamped the list 34 seconds before the final link, while my build uses one timestamp for both) |

The path replacement was done on a copy of my image for comparison only. It changes text, not code, and it is the only normalisation applied. Anyone can check that the raw comparison already shows 0 code differences. The path replacement affects only the string area.

**Is it identical to the genuine kernel?** Not as built: 26 bytes differ even after normalising the path, and the compressed `zImage` differs in size by 56 bytes (its decompressor stub differs in 20 bytes, which hold sizes that follow from the different compressed length). The **compiled code is identical**, and the remaining differences are explained by build labels and a build fingerprint. I therefore state: *functionally identical code; not a bit-identical file.*

### 6.5 Similarities and differences with the GT-I8200N kernel from the same research

| Comparison | Code (`.text`) identical |
|---|---|
| My Build C (path normalised) vs genuine **GT-I8200** (OC1) image | **100.000%** (0 bytes differ) |
| My Build C vs genuine **GT-I8200N** (OC1, changelist 2824661) image | 99.300% (35,999 bytes differ) |
| Genuine GT-I8200 vs genuine GT-I8200N | 99.300% |

So the match is specific to the GT-I8200 kernel. A different, equally plausible kernel (the N variant) is measurably different.

### 6.6 Two independent builds agree

I ran the project script (`tools/kernel-build/build-golden-kernel.sh`) in a fresh directory with a different path of the same length. Its C build again differs from the genuine image in exactly **26 bytes after path normalisation and 0 bytes in the code**. Comparing my two C builds with each other (both normalised) leaves exactly 20 differing bytes: the build fingerprint. So the build is repeatable.

---

## 7. What this means for the "trustworthy base" question

| Question | Answer from this build |
|---|---|
| Does `44afe4c` compile with the original toolchain? | **Yes**, kernel and 20 modules. |
| Does it reproduce a genuine Samsung GT-I8200 kernel's compiled code? | **Yes** for the I8200XXUAOC1 (March 2015) image I could compare: 100% of code bytes, 100% of symbols, with the Samsung production options on. |
| Is the Koloses source "the I8200XXUAOC1 source"? | For every file that is compiled into this kernel: **yes, as far as the compiled result can show**. This makes the repository's "OC1" label credible for the code. The most plausible explanation of the 13 January 2016 date in its leftover files is that it marks when the packager made a development build (inference, not proven). Any later release (e.g. I8200XXUAPB1) may have identical compiled code too, but this build cannot tell. |
| Was any compiled file altered? | Not in any way that changes the compiled output for this configuration. |
| Is it authenticated against Samsung's own download? | **No.** Still missing: Samsung's official package and the PB1 firmware kernel. |
| Which files does it not cover? | Source files not compiled into this kernel: other boards' code, modules (no stock `.ko` files to compare), documentation, and drivers turned off in this configuration. |

**Conclusion:** the evidence is now sufficient to treat `44afe4c` as a **trustworthy base for further experimentation**, with the standing conditions that the official package comparison is still pending and no claim is made about any behaviour on a phone. This is my assessment, not an authentication. The decision to proceed is yours.

---

## 8. Limitations

1. The reference image is a community file. Its genuineness is supported by embedded Samsung build-farm strings and a changelist match, not proven.
2. One firmware version (OC1) was compared. The newest, I8200XXUAPB1, is not available to me.
3. Only compiled code was compared. Modules were built but cannot be compared (no stock `.ko`).
4. The path normalisation was applied after the build, to my image copy, on equal-length text.
5. Bit-identity does not hold (26 bytes after normalisation; build fingerprint cannot match).
6. Host helper programs were built with GCC 13 and the single timeconst script used a run-time shim. Neither affects target code, as the 100% code match shows, but it is a deviation from Samsung's 2016 host environment.
7. Nothing was run on any phone, so nothing here shows that the kernel boots or any hardware works.
8. Samsung's `SEC_RESTRICT_*` options are in Builds B and C only. A ROM kernel will need a deliberate decision about them.

---

## 9. Reproducing this (about 5 minutes, 6 GB, no phone, no root)

```sh
git clone <this repository> && cd galaxy-s3
tools/kernel-build/build-golden-kernel.sh /path/to/short/workdir 4
```

Requirements (not installed by the script): git, make, gcc (host helper programs only), perl, python3, tar, gzip, sed, bc, curl, an x86-64 Linux host, network access to GitHub and android.googlesource.com. The work directory's absolute path must be at most 92 characters, because the script pads the source folder name so the full source path has 94 characters.

What the script does: clone the repository and verify commit `44afe4c…` and tree `0eebf6f9…`; fetch the AOSP toolchain and verify commit `d73a051…` and compiler banner; make the experimental copy and run `make mrproper`, recording the 899 removed files; build A, B and C; download the community reference image and verify its SHA-256; print the byte comparison. Expected final lines: variant C, "differing bytes after path normalisation: 26; in .text: 0".

For the symbol comparison (needs `pip install vmlinux-to-elf` in a virtualenv):
```sh
kallsyms-finder out-C/arch/arm/boot/Image > ours.syms      # decompressed image
kallsyms-finder reference.Image > ref.syms                  # decompress the reference zImage's gzip stream first
python3 -I tools/kernel-build/compare-symbols.py ref.syms ours.syms
```

## Appendix A: Exact commands (the interactive session; the script runs the same steps)

```sh
# source and toolchain
git clone https://github.com/Koloses/kernel_i8200 pristine && git -C pristine checkout --detach 44afe4cf6023bf39c18bad72185003a40915fad2
git clone --depth 1 --branch jb-mr1-release https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6 toolchain
cp -a pristine experimental
CROSS=$PWD/toolchain/bin/arm-eabi-
(cd experimental && make ARCH=arm CROSS_COMPILE=$CROSS mrproper)

# Build A (first attempt without the shim failed; second with the shim succeeded)
make O=out-A ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc pxa986_golden_rev02_defconfig
make O=out-A ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc silentoldconfig
make -j4 O=out-A ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc PERL=tools/kernel-build/perl-shim.sh zImage

# Build B: as A, plus, before silentoldconfig
scripts/config --file out-B/.config --enable CONFIG_SAMSUNG_PRODUCT_SHIP --enable CONFIG_SEC_RESTRICT_ROOTING \
   --enable CONFIG_SEC_RESTRICT_SETUID --enable CONFIG_SEC_RESTRICT_FORK --enable CONFIG_SEC_RESTRICT_ROOTING_LOG

# Build C: as B, from a copy (without .git) at a 94-character path, with
export KBUILD_BUILD_USER=se.infra KBUILD_BUILD_HOST=SWDB2803 KBUILD_BUILD_VERSION=2 \
       KBUILD_BUILD_TIMESTAMP='Wed Mar 18 09:23:47 KST 2015'
make -j4 O=out-C ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc PERL=tools/kernel-build/perl-shim.sh LOCALVERSION=-2825398 zImage
make -j4 O=out-C ARCH=arm CROSS_COMPILE=$CROSS HOSTCC=gcc PERL=tools/kernel-build/perl-shim.sh LOCALVERSION=-2825398 modules
```

The generated final configuration of Build B/C is `docs/build-logs/golden_rev02_ship.config`. The environment record is `docs/build-logs/environment.txt`. All logs are in `docs/build-logs/`.

## Appendix B: Output hashes (informational; images are not committed)

| Run | File | Bytes | SHA-256 |
|---|---|---|---|
| A (102-char path) | `zImage` | 3,871,032 | `8fa2aab1cb540d43c2063a274253509e5e7ebdc1b8261e738651d0906887e968` |
| B (102-char path) | `zImage` | 3,872,544 | `ab4d92b3a5a46c7b7fc7f96208e25762bb4aacdc9dcad20d64ef3dff0354b3bf` |
| C (94-char path) | `zImage` | 3,872,040 | `90078b324298ed91a3043d20c859b7f73bb1c675611decd199b6851d18665401` |
| C | decompressed `Image` | 8,455,412 | `eeb9b0e7dcc142409b080728c19270aef924a385d452b57d10cca7b92d227194` |
| C | `vmlinux` | 102,085,450 | `6c95fec6be10d8c60b6ac1efe19c59a39d76ad8ae5b442b4720dcf86fe8101c0` |
| C | final `.config` | 78,597 | `a7ca2a92a1124997a1a7eb73cc597961260a85aa20e33c8b7da4d4ebf800a1ac` |
| Script run C | `zImage` | 3,872,080 | `d8770e8f903e50be029e8d96d31053d63c0c85a1e8223ce2d2b67ebce1f992ec` |
| Genuine reference | `zImage` | 3,871,984 | `52795a2e64095cd525b27afdd56f4b601dfd8d9ba6e542088ef70c8bc2650860` |

Hashes of the same variant differ between folders because the folder path is embedded in the image.

## Appendix C: Files added by this phase

| Path | Purpose |
|---|---|
| `tools/kernel-build/build-golden-kernel.sh` | Reproduction script |
| `tools/kernel-build/perl-shim.sh` | Run-time shim for the one Perl-incompatible script (no source change) |
| `tools/kernel-build/compare-symbols.py` | Symbol-table comparison |
| `docs/build-logs/` | Complete logs, failure log, environment record, deleted-file list, final configuration |
