# Phase 7, Parts C and D: build environment, disk space, and the official Samsung inputs still needed

Computer-only. No full source tree was downloaded or cloned, no system-wide package was installed, no phone was touched. Everything downloaded is listed in section 7. Logs: [build-logs/phase7/](build-logs/phase7/).

Labels: **MEASURED** (on this computer, with real data), **ESTIMATE** (my judgment, basis stated), **SOURCE** (read in sources), **UNKNOWN**.

## 1. Answers

| Question | Answer |
|---|---|
| Disk for source plus output | Estimated **75 to 175 GiB** in use (section 2). **Minimum safe free space at the start: 200 GiB. Recommended: 250 GiB** (300 GiB if you want a compiler cache and a second output folder). Same number must be free on the filesystem that holds the source, not just in total. |
| Build environment | An **Ubuntu 16.04 userland** (OpenJDK 8, Python 2.7, make 4.1) in a **chroot** (or a container if you already have one) on the Ubuntu 24.04 host, with **`repo` and git run on the host**. Section 4. |
| Java, Python, repo versions | OpenJDK **8** (any 8u build; Android 7's `main.mk` requires `1.8` in both `java -version` and `javac -version`); Python **2.7**; make **4.1** (Ubuntu 16.04's); repo launcher **2.71** (newest tag `v2.72`), which needs Python 3.6 or newer. Section 3. |
| System-wide changes needed | None for the recommended route (it needs `sudo` to run `chroot`/`mount`, but installs no host package). |
| What blocks Phase 8 here | Official firmware and partition data (Part D), your decisions from the SELinux document, and a machine with the disk. |

## 2. Disk requirements (Part C, items 1 and 2)

### What was measured
- All **479** projects in the LineageOS `cm-14.1` manifest (`3053abb1…`) resolve and were fetched as *tree metadata only* (blobless depth-1; no file contents). **586,344 files** in total. The default `repo` group set (467 projects, without the 12 "notdefault" ones) has **488,354 files**; the 12 optional projects add 97,990 files (mostly `tools/idea`). Data: [data/lineage-14.1-file-counts.tsv](data/lineage-14.1-file-counts.tsv).
- Real shallow checkouts (`--depth 1`, working tree plus `.git`) of **14 projects** covering 203,486 files (**42 % of the default files**): **13.28 GiB**, average 68.4 KiB per file. It varies a lot by project: `external/clang` 10.5 KiB/file, `prebuilts/deqp` 6.8, `frameworks/base` 75.3 (2.4 GiB), `prebuilts/gradle-plugin` 98.6 (2.2 GiB), `prebuilts/tools` 325.6 (2.7 GiB), `prebuilts/sdk` 683.8 (1.2 GiB), `prebuilts/clang` 1,117.8 (0.7 GiB). The 11 projects measured in this phase were deleted after measuring; the other 3 are from Phase 6.

### Estimate
| Part | Estimate | Basis |
|---|---|---|
| Source, shallow (`repo sync -c --depth=1 --no-tags`), default groups | **25 to 45 GiB** | 13.3 GiB measured for 42 % of the files, biased toward big projects; the other 58 % are mostly many small `external/*` and `packages/*` repositories at roughly 10 to 75 KiB per file (7 to 25 GiB), plus unsampled prebuilts |
| Build output `out/` for one `userdebug` device | **40 to 70 GiB** | **Not measured.** General experience with Android 7 builds; treat as an assumption and measure in the first real build |
| Compiler cache (optional) | 25 to 50 GiB | typical, not measured |
| Scratch for kernel experiments, logs | 5 to 10 GiB | this project's own copies were about 1 to 2 GiB each |
| Isolated Ubuntu userland | about 0.4 GiB (measured 385 MiB with Python, OpenJDK 8, make) | MEASURED; a full build tool set adds more |
| **Total in use** | **about 75 GiB (low) to 175 GiB (high)** | sum of the rows |

- Full-history syncs are much bigger. Google's current published figure for modern Android is 400 GiB (250 to check out with history, 150 to build, 64 GiB RAM). That is for a far newer release and for full history, which this project does not need; I use it only as a warning that a plain `repo sync` without `--depth=1` is not planned.
- **Minimum safe free space: 200 GiB** (covers the high estimate with a small margin). **Recommended: 250 GiB**.
- **Staged protocol so nothing runs out of space half-way** (to be used in Phase 8): refuse to start unless 200 GiB is free; during `repo sync`, stop if free space falls below 80 GiB; before the build starts require 100 GiB free; after the first sync record the real size and replace this estimate. `tools/build/preflight.sh` now defaults to the 200 GiB gate.
- Memory and CPU: this sandbox (4 CPUs, 15 GiB RAM) is not a suitable build machine. I do not know your ThinkPad's RAM, disk type or whether Ubuntu 24.04 runs natively or in WSL. For a full Android 7 build, 16 GiB of RAM plus 16 GiB of swap and an SSD are a sensible floor (ESTIMATE). Please report: free disk on the filesystem you will use, RAM, CPU cores, and native Ubuntu or WSL2.
- If it is WSL2: keep the source and output on the Linux (ext4) disk, never under `/mnt/c`, and check the virtual disk's maximum size first. (Not tested; I do not know your setup.)

## 3. Compatible tool versions (Part C, item 3)

| Tool | Requirement | Evidence | Chosen |
|---|---|---|---|
| Java | OpenJDK 8: `java -version` and `javac -version` must both contain `1.8` | SOURCE: `build/core/main.mk`, cm-14.1 | MEASURED: Ubuntu 16.04 release package (8u77) reports `1.8.0_03-Ubuntu` and satisfies it. 16.04 updates carry 8u191 (apt resolved it; I could not fetch it here, section 7). |
| Python | Python 2.7 (build and release tools are Python 2 source) | SOURCE: `print` statements in `build/tools/releasetools/build_image.py` | MEASURED: 2.7.11 runs in the chroot; `python` must be a link to `python2.7` inside it. 16.04 updates carry 2.7.12. **Ubuntu 24.04 has no `python2` in its archive** (package index check). |
| make | `main.mk` requires 3.81 or newer | SOURCE | 4.1 (Ubuntu 16.04), MEASURED present. Host 24.04 has 4.3; with it a probe of `$(call my-dir)` returned empty (cause not isolated), so I do not rely on it. |
| repo launcher | Python 3.6 or newer | SOURCE: launcher `MIN_PYTHON_VERSION` | 2.71 from Google's download bucket (MEASURED to start on this host); newest tag in `git-repo` is `v2.72`. Pin the tag you actually use in Phase 8. |
| Python for `repo` | 3.6+ | | The Ubuntu **16.04 userland has Python 3.5, too old**, so run `repo` and git **on the host** (Ubuntu 24.04: Python 3.12), outside the chroot. |
| Other packages (bison, flex, gperf, zip, unzip, libncurses, and so on) | standard Android build dependencies | not verified here | Install inside the chroot only; take the list from the LineageOS 14.1 documentation when Phase 8 starts. |

Package availability by Ubuntu release (MEASURED from the archive indexes): `openjdk-8-jdk` is in 16.04, 18.04, 22.04 and 24.04; `python2.7` is in 16.04, 18.04 and 22.04 but **not 24.04**; make is 4.1 (16.04, 18.04) or 4.3 (22.04, 24.04).

## 4. Isolated build environment (Part C, items 4 and 5)

| Option | Fit | Notes |
|---|---|---|
| **A. Ubuntu 16.04 chroot made from the official `ubuntu-base` tarball (recommended)** | Best | No host packages. Needs `sudo` for `chroot`/`mount`. Delete the folder to remove it (unmount `proc` and the source bind mount first). Tested here as far as the sandbox allows (below). |
| B. Docker or Podman container with an Ubuntu 16.04 image | Good | Only if you already run one; installing a container engine is a system-wide change that needs your approval. The sandbox here has the Docker client but no running daemon, so this was **not tested**. |
| C. VM (KVM, VirtualBox) or LXD | Fine, heavier | Not tested. |
| D. Native build on Ubuntu 24.04 | Not recommended | No Python 2 in the archive; Android 7's host tools are widely reported to need patches with a current glibc (not tested here); would need system-wide package changes. |
| E. Ubuntu 22.04 userland | Second choice | Has Python 2.7 and OpenJDK 8 but make 4.3 and a newer glibc than 16.04. |

### What I actually ran for option A (all inside a scratch folder here)
1. Downloaded `ubuntu-base-16.04.6-base-amd64.tar.gz` (42.8 MB) and checked its SHA-256 against Ubuntu's `SHA256SUMS`: `9c160b52…49a0`, **match**. (Both came from the same host; on your machine also verify the `SHA256SUMS.gpg` signature.)
2. Extracted it, entered it with `chroot`, confirmed `Ubuntu 16.04.6 LTS`, x86_64.
3. Installed Python 2.7.11, OpenJDK 8u77 (JDK, headless) and make 4.1 into it. `apt` through this sandbox's proxy answered `405` for several requests and `security.ubuntu.com` is blocked, so I fetched the 56 `.deb` files from the release pool with `curl` and installed them offline. On a normal connection `apt-get install` does this in one step.
4. Mounted `/proc` inside the chroot (the Java package scripts need it), finished the install, and ran: `python --version` → `Python 2.7.11+`; `make --version` → `GNU Make 4.1`; `java -version` and `javac -version` → `1.8.0_03-Ubuntu`. Unmounted `/proc`. Log: [05-isolated-userland-test.log](build-logs/phase7/05-isolated-userland-test.log).
5. The host system was not modified. Nothing was built in it.

Not run: `apt-get install` of the full Android build dependency list, `repo` inside or outside it, any build, bind-mounting a source tree.

### Proposed layout for Phase 8
```
host (Ubuntu 24.04)                       chroot (Ubuntu 16.04 userland)
  /srv/lineage14        source tree  -->    /src          (bind mount)
  repo + git (python3)  runs here           make, JDK 8, python2.7, build tools
  ccache dir            (optional)   -->    /ccache       (bind mount)
```
Enter with `sudo mount --bind` for the source, `proc` and `dev`, then `chroot`; leave and unmount in reverse. Keep the source on a filesystem with at least the free space above. Run the build driver (`tools/build/build-lineage.sh`) with `repo` from the host side and the build step inside the chroot; the driver will need a small change for that and is not changed yet.

## 5. Part D: official Samsung inputs and device partition data still needed

Nothing below exists in this repository. None of it may be replaced by community files, community partition numbers, the rooted dump, or the Koloses tree. Phase 2 already documented why each community value is unreliable; this is the exact to-do list.

### 5.1 Files from Samsung (your action, or allow Samsung's hosts here)
| # | Item | Official source | Used for | What to record |
|---|---|---|---|---|
| D1 | **Kernel source package** for GT-I8200 | `opensource.samsung.com` (search `GT-I8200`) | Compare with the pinned Koloses commit; settle which release it is | Page screenshot, exact package name, models listed, upload date, file size, **SHA-256 you compute** |
| D2 | **Firmware**, GT-I8200 only (not I8200N, I8200L, I8200Q, I8190): PDA `I8200XXUAPB1` is the newest build found (Phase 2); region/CSC to match your phone | Samsung's own update server ("FUS"), via an open-source client run on your computer | Vendor files (GPU, HAL, firmware), `build.prop` identity checks, boot image header, ramdisk files | Every file name and size as downloaded, **SHA-256 of each**, the version strings, the date, which tool you used. Samsung's `.tar.md5` trailer only detects corruption, it does not prove origin. |
| D3 | Contents of the AP package: `boot` (kernel) image, `recovery` image, `system` image; and a **PIT file if the package contains one** | inside D2 | Boot header values, partition table, system files | List the archive first and record what is in it (the layout is UNKNOWN to me) |
| D4 | CP (modem) and CSC packages | inside D2 | Not needed for the first build; needed for cellular later | Same hash record |

Access options: (1) you download D1 and D2 on your computer and supply them with the hashes; or (2) you allow `opensource.samsung.com` and Samsung's firmware hosts in this environment's network settings, and I fetch them. I have not changed any environment setting. Mirrors (sammobile and similar) are not acceptable as proof of origin.

### 5.2 Values to read from those files, and the BoardConfig setting each fills
| BoardConfig setting | Value comes from | Currently |
|---|---|---|
| `BOARD_KERNEL_BASE`, `BOARD_KERNEL_PAGESIZE`, ramdisk offset, tags offset | header of the official boot image (unpack it with a standard tool) | unset; community trees conflict (ramdisk offset `0x01000000` vs `0x11000000`) |
| `BOARD_KERNEL_CMDLINE` | the same header; cross-check with `/proc/cmdline` on the phone | unset; community trees say empty |
| `BOARD_BOOTIMAGE_PARTITION_SIZE`, `BOARD_RECOVERYIMAGE_PARTITION_SIZE`, `BOARD_SYSTEMIMAGE_PARTITION_SIZE`, `BOARD_USERDATAIMAGE_PARTITION_SIZE` | the PIT (partition sizes and offsets), or the phone's `/proc/partitions` | unset; three conflicting community sets, one of them clearly a placeholder |
| `BOARD_FLASH_BLOCK_SIZE` | the storage's erase/block size, from the PIT or the phone | unset |
| Filesystem types, mount flags, partition by-name links | official ramdisk `fstab` and the system image header | claimed only (community ramdisk) |
| Vendor tree | official system image, through `extract-files.sh` | empty |

### 5.3 Read-only facts from your own phone (optional alternative to the PIT; I will not touch the phone)
If the firmware has no PIT, the owner can supply the output of read-only commands (USB debugging on; nothing written or changed), for example `cat /proc/partitions`, `ls -l /dev/block/platform/*/by-name`, `cat /proc/cmdline`, `cat /proc/mounts`, and the model, board, baseband and build properties. I record them as "supplied by owner, date" and cross-check against the firmware. These commands only read. This is documentation for you; I have issued none.

### 5.4 Identity gates before anything is used
Model `GT-I8200` (not `GT-I8200N`, `GT-I8200L`, `GT-I8200Q`, `GT-I8190`), device `goldenvess3g`, a fingerprint that matches the downloaded build, no root artifacts. `extract-files.sh` already enforces these and needs `PROVENANCE.txt` (source, package name, size, SHA-256, origin). Whether the phone has NFC is still to be confirmed by the owner (look only).

### 5.5 What stays unknown until then
Boot image offsets and command line, every partition size, storage block size, filesystem layout, which Samsung release the Koloses kernel is, whether the sensors `sensord` service matters, and every vendor file's real content. The build guards from Phase 6 refuse to build until these exist.

## 6. Tools added or changed
- `tools/build/measure-source-size.py`: counts files per manifest project without downloading contents (a first version tried to measure sizes with `git ls-tree -l`, which would have fetched every file; I stopped it within minutes and deleted what it fetched).
- `tools/build/preflight.sh`: default free-space gate raised from 100 to 200 GiB.

## 7. Everything downloaded in this part
Tree metadata of all 479 manifest projects (deleted); shallow clones of 11 projects for size measurement (deleted); `ubuntu-base` tarball and 56 Ubuntu 16.04 packages (kept in the scratch folder, not in the repository); Ubuntu package indexes; `repo` launcher; a flex package unpacked in scratch for the policy compiler. Nothing from the full source tree. Not obtainable here: Ubuntu 16.04 *updates* (python2.7 2.7.12, OpenJDK 8u191) because `security.ubuntu.com` is blocked by this sandbox; this limits what I could test, not what you can do.
