# Phase 9B: Isolated Ubuntu 16.04 build environment preparation

**Status: PARTIALLY READY.** The existing script works end to end (fetch, verify, extract, install, enter, teardown) and Java 8, Python 2.7 and make 4.1 all work inside it. It was run on a stand-in for your host, not on your WSL2 machine, and `/home/overm/android/` was never reachable. Section 9 lists what is still open and the commands to close it on your ThinkPad.

Labels: **MEASURED** (run in this session), **SOURCE** (read in the repo), **NOT VERIFIED** (could not be tested here).

No script or source file was modified. This document is the only change.

## 1. Where this was tested

The session ran in a cloud container, not on your ThinkPad:

| | This test | Your machine |
|---|---|---|
| OS | Ubuntu 24.04.5 LTS (the same release as your WSL distribution) | Ubuntu 24.04 under WSL2 |
| Privileges | root | `sudo` |
| Kernel | plain Linux 6.18 | Microsoft WSL2 kernel |
| Workspace | a scratch directory standing in for the Android workspace | `/home/overm/android/` |

Anything specific to WSL2, such as mount behaviour, `/dev`, DNS and ext4 on the virtual disk, is **NOT VERIFIED**. Only the Ubuntu 24.04 userland behaviour was tested.

## 2. What was already working (Phase 7/8 claims, re-checked)

- `fetch`, `extract` and `enter`, plus `python2.7`, OpenJDK 8 and make 4.1 inside the chroot, were reported working in Phase 7 ([build-logs/phase7/05-isolated-userland-test.log](build-logs/phase7/05-isolated-userland-test.log)). All of that re-ran cleanly today with the script itself, not with hand-run commands.
- The Phase 7 gap was `install`. The script says "NOT TESTED in the sandbox". It is now tested: the real `apt-get` run completed with exit code 0 in 68 seconds (section 5).

## 3. Script behaviour, step by step

`tools/build/xenial-userland.sh` is 53 lines. `bash -n` passes.

| Step | Result | Notes |
|---|---|---|
| `fetch ROOT_PARENT` | **MEASURED, works.** Downloads `ubuntu-base-16.04.6-base-amd64.tar.gz` (42,776,806 bytes), `SHA256SUMS` and `SHA256SUMS.gpg`. `sha256sum -c` printed `OK`. | Details in section 4. |
| `extract ROOT_PARENT` | **MEASURED, works.** Unpacks to `ROOT_PARENT/xenial-root`. A second run refused with "exists; refusing to overwrite". | It requires root. Without root it exits with a clear message. |
| `install ROOT_PARENT` | **MEASURED, works.** Writes a `sources.list` with `xenial`, `xenial-updates` and `xenial-security`, runs `apt-get update` and installs the package list. Ends by printing the java, javac, python and make versions. | The package list was not checked against the LineageOS 14.1 docs (section 6). It leaves `/proc` mounted for the install and unmounts it afterwards. |
| `enter ROOT_PARENT [SRC] [CMD...]` | **MEASURED, works.** Mounts `proc` and `/dev` and bind-mounts SRC at `/src`. It runs the command under `env -i` and unmounts everything on exit. | Edge cases tested: a failing command (exit code 1 came through, 0 mounts left); two concurrent sessions (mounts stack, and closing the inner one left the outer one intact, 3 mounts); no SRC (works). |
| `teardown ROOT_PARENT` | **MEASURED, works.** Reports "no mounts remain" and prints the `rm -rf` command without running it. | That is the intended safe behaviour. |

### Problems found in the script (not fixed)

1. **GPG verification is not performed.** The script only prints a reminder. The SHA-256 comes from `SHA256SUMS` on the same server, fetched over plain `http://`, so the check detects corruption and does not prove origin. The `.gpg` download is also wrapped in `|| true`, so a missing signature file is silent. This is not a bypass, because the SHA-256 check is enforced and fails the script. The signature step is manual and is not enforced by the script.
   - **A trusted route exists with no keyserver:** the `ubuntu-keyring` package already installed on Ubuntu 24.04 contains the signing key `843938DF228D22F7B3742BC0D94AA3F0EFE21092`, "Ubuntu CD Image Automatic Signing Key (2012)". **MEASURED:** the command below reported `Good signature` (see section 4).
   - A keyserver fetch failed here ("No data"), so use the keyring file instead.
2. **No unprivileged user inside the chroot.** `enter` runs as root with `HOME=/root`. Files written to the bind-mounted workspace are owned by root. **MEASURED:** a file created in `/src` showed owner `root`. On `/home/overm/android/` that would leave root-owned files in your workspace. Android builds also dislike running as root. Section 7 gives a safer way to enter; the script does not need to change.
3. **`resolv.conf`** is copied from the host only during `install`. If your WSL DNS changes, copy it again before `apt` or network use inside the chroot.
4. **No `/sys`, `/dev/pts` or `/dev/shm` mounts.** Nothing needed them here (install and the version checks passed). **NOT VERIFIED** for a real Android build.
5. **Fixed values.** The mirror URL and the version number are hard-coded; this is intended.

## 4. Fetch and verification: exact data

```
ubuntu-base-16.04.6-base-amd64.tar.gz   42,776,806 bytes
sha256 9c160b522568c0c3f2c396cfe7c966f1a63aa1a5e9f6f966a74fdf3571ad49a0   (matches SHA256SUMS; also matches Phase 7)
SHA256SUMS.gpg: signed 2020-10-20 by RSA 843938DF228D22F7B3742BC0D94AA3F0EFE21092
```

Signature check that worked (run from the download folder):

```bash
gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
    --verify SHA256SUMS.gpg SHA256SUMS
# gpg: Good signature from "Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>"
# gpg: WARNING: This key is not certified with a trusted signature!   <- normal, no web of trust here
```

That key is in the `ubuntu-keyring` package (here version 2023.11.28.1), which comes from the host distribution's own archive. Nothing was downloaded to trust it. I did not check that your WSL has the same package version.

## 5. Package versions

### Isolated environment: Ubuntu 16.04.6 LTS, x86_64 (**MEASURED**)

| Tool | Version in the chroot | Requirement |
|---|---|---|
| OpenJDK | `openjdk version "1.8.0_292"` (package `openjdk-8-jdk 8u292-b10-0ubuntu1~16.04.1`) | `java -version` and `javac -version` must both contain `1.8` |
| javac | `javac 1.8.0_292` | same |
| Python | `Python 2.7.12` (package `python2.7 2.7.12-1ubuntu0~16.04.18`). `/usr/bin/python` points to `/usr/bin/python2.7`. | Python 2.7 |
| GNU Make | `GNU Make 4.1` (package `make 4.1-6`). A test Makefile printed `$(MAKE_VERSION)` as `4.1`. | 3.81 or newer |
| Python 3 | **not installed** in the chroot | `repo` needs 3.6+ and runs on the host, not in the chroot. |

Phase 7 had only the 16.04 release-pocket versions (Python 2.7.11, OpenJDK 8u77). With the full `xenial-updates` and `xenial-security` pockets it now gets 2.7.12 and 8u292.

### Packages named in the script, as installed

```
bc 1.06.95-9build1                    bison 2:3.0.4.dfsg-1               build-essential 12.1ubuntu2
ca-certificates 20210119~16.04.1      ccache 3.2.4-1                     curl 7.47.0-1ubuntu2.19
flex 2.6.0-11                         g++ / g++-multilib / gcc / gcc-multilib 4:5.3.1-1ubuntu1
git / git-core 1:2.7.4-0ubuntu1.10    gnupg 1.4.20-1ubuntu3.3            gperf 3.0.4-2
lib32ncurses5-dev 6.0+20160213-1ubuntu1                                  lib32z-dev -> lib32z1-dev 1:1.2.8.dfsg-2ubuntu4.3
libc6 / libc6-dev-i386 2.23-0ubuntu11.3                                  libgl1-mesa-dev 18.0.5-0ubuntu0~16.04.1
libssl-dev 1.0.2g-1ubuntu4.20         libx11-dev 2:1.6.3-1ubuntu2.2      libxml2-utils 2.9.3+dfsg1-1ubuntu0.7
rsync 3.1.1-3ubuntu1.3                unzip 6.0-20ubuntu1.1              x11proto-core-dev 7.0.31-1~ubuntu16.04.2
xsltproc 1.1.28-2.1ubuntu0.3          zip 3.0-11                         zlib1g-dev 1:1.2.8.dfsg-2ubuntu4.3
python2.7 2.7.12-1ubuntu0~16.04.18    openjdk-8-jdk (and -headless, jre-headless) 8u292-b10-0ubuntu1~16.04.1
make 4.1-6 (pulled in by build-essential)
```

`lib32z-dev` is a virtual package name, so apt resolved it to `lib32z1-dev`. This works but is fragile.

Installed root filesystem size: **1.1 GiB** (Phase 7 measured 385 MiB for only Python, JDK and make).

## 6. Package list: what is not verified

The comment in the script says the list was "taken from memory". I tried to compare it with the LineageOS 14.1 documentation. The current wiki serves only modern pages (the per-device build page returned content for a modern release, not 14.1), so I could not obtain an authoritative 14.1 list and I did not guess one. These packages are commonly part of Android 7-era build instructions but are **not** in the script. All exist in Ubuntu 16.04, and I did not install them:

| Package | Candidate in xenial |
|---|---|
| `imagemagick` | 8:6.8.9.9-7ubuntu5.16 |
| `liblz4-tool` | 0.0~r131-2ubuntu2 |
| `libncurses5-dev` | 6.0+20160213-1ubuntu1 |
| `libsdl1.2-dev` | 1.2.15+dfsg1-3ubuntu0.1 |
| `libwxgtk3.0-dev` | 3.0.2+dfsg-1.3ubuntu0.1 |
| `lzop` | 1.03-3.2 |
| `pngcrush` | 1.7.85-1 |
| `schedtool` | 1.3.0-1 |
| `squashfs-tools` | 1:4.3-3ubuntu2.16.04.3 |
| `maven` | 3.3.9-3 |
| `lib32readline6-dev` | 6.3-8ubuntu2. **`lib32readline-dev`, the name used in some lists, does not exist in xenial.** |

Decide the final list from the 14.1 documentation before the ROM build phase. Missing build dependencies show up quickly as errors, so they are cheap to add inside the chroot and need no host change.

## 7. Repositories: current state (**MEASURED**, HTTP status)

| URL | Result |
|---|---|
| `cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/SHA256SUMS` (http and https) | 200 |
| `archive.ubuntu.com/ubuntu/dists/xenial/Release` | 200 |
| `archive.ubuntu.com` `xenial-updates`, and `security.ubuntu.com` `xenial-security` | 200 (indexes and packages downloaded) |
| `old-releases.ubuntu.com/ubuntu/dists/xenial/` | 404 (not applicable; xenial was never moved there) |

- **The original Ubuntu 16.04 repositories are still available**, so no substitute release was needed and none was used. Ubuntu 20.04 and 22.04 were not used.
- Xenial's standard support ended in April 2021. The archive is frozen at that state: the versions in section 5 are the last standard-support builds. Later ESM fixes sit behind Ubuntu Pro (`esm.ubuntu.com`), which was neither used nor needed here. Treat this environment as an old toolchain for building an old Android release, not a place to run network-facing services.
- In the sandbox, `security.ubuntu.com` was blocked in Phase 7 and reachable now. If your network blocks it, delete the `xenial-security` line in the chroot's `/etc/apt/sources.list`; the other two pockets still work.
- Everything came from official Ubuntu hosts. No third-party repositories, PPAs or unsigned sources were used, and no apt security checks were turned off.

## 8. Using the environment

Placeholders: `ROOT_PARENT` is the folder holding the tarball and `xenial-root` (for example `/home/overm/xenial`). Keep it on the Linux filesystem, never under `/mnt/c`. The script path is relative to the repository.

```bash
# one-time, no root needed for fetch
bash tools/build/xenial-userland.sh fetch   ~/xenial
cd ~/xenial && gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
                   --verify SHA256SUMS.gpg SHA256SUMS         # must say "Good signature"; then cd back
sudo bash tools/build/xenial-userland.sh extract ~/xenial
sudo bash tools/build/xenial-userland.sh install ~/xenial     # prints the Java/Python/make versions at the end
```

**Enter** (the Android workspace appears at `/src`):

```bash
sudo bash tools/build/xenial-userland.sh enter ~/xenial /home/overm/android
```

**Exit:** type `exit` or press Ctrl-D. The script's `trap` unmounts `/src`, `/dev` and `/proc` even when the command fails (**MEASURED**). Then confirm:

```bash
sudo bash tools/build/xenial-userland.sh teardown ~/xenial   # must say: no mounts remain
```

**Remove it completely:** run teardown first, then the `rm -rf '.../xenial-root'` line it prints. Never `rm -rf` while it says "still mounted below": that would delete your workspace through the bind mount.

Safety notes:
- Do not close the terminal window abruptly or run `wsl --shutdown` while inside. After either, run `teardown` and check `grep xenial-root /proc/mounts` is empty before deleting anything.
- Two sessions at once work, because mounts stack. Exit them in reverse order and run `teardown` last.
- As the script stands you are root inside, and files created in `/src` are owned by root. Before the real build phase, either add a normal user inside the chroot (matching your uid, typically 1000) and `chroot --userspec`, or fix ownership afterwards. This was identified only; I did not change the script.
- Inside, `PATH` is only `/usr/sbin:/usr/bin:/sbin:/bin`, so nothing from your host leaks in.

## 9. Workspace access (task 9)

**Not verified for `/home/overm/android/`: that path does not exist in this session.**

Verified with a stand-in directory bind-mounted at `/src`: read, write, symlinks, executable bits, a case-sensitive pair of files (`Case` and `CASE` coexisted), and `df` showing the real filesystem. Writes appeared immediately on the host side. The one caveat is root ownership (section 3, item 2).

To verify on your machine, run these (the `touch` and `rm` inside write only a marker file in your workspace):

```bash
sudo bash tools/build/xenial-userland.sh enter ~/xenial /home/overm/android /bin/bash -c \
  'df -h /src | tail -1; touch /src/.chroot-probe && ls -l /src/.chroot-probe && rm /src/.chroot-probe; python --version; make --version | head -1; java -version; javac -version'
```

Check the workspace is on ext4 (`df -T /home/overm/android`), not a `/mnt/c` drvfs mount.

## 10. Ubuntu 24.04 host unchanged (**MEASURED**)

Before and after the full run, these were identical:

| Item | Before and after |
|---|---|
| Installed packages | 837 (`dpkg-query` list hash `6901763c…a134` unchanged) |
| `/etc/apt/sources.list`, `ubuntu.sources`, `docker.list` | same hashes |
| Host `java`, `python3`, `make` | same (Python 3.13.18, GNU Make 4.3; no `python2` on the host) |
| Mount table | same (26 entries, same hash) |

Everything installed or downloaded lives under the scratch folder's `xenial-root` and the tarball. Only `chroot` and `mount` used root. Nothing global was installed or downgraded. The host `python` stays as it was; the inside `python` is a link to `python2.7` and exists only inside the chroot.

## 11. What was installed or downloaded

| Item | Where | Size |
|---|---|---|
| `ubuntu-base-16.04.6-base-amd64.tar.gz`, `SHA256SUMS`, `SHA256SUMS.gpg` | scratch folder (not in the repo) | 42.8 MB |
| About 17.3 MB of apt indexes and the packages of section 5 (with dependencies) | inside `xenial-root` only | root fs 1.1 GiB |

Not done, per the restrictions: no LineageOS source, no repo sync, no ROM build, nothing touched in the Samsung kernel source, no SELinux or Binder patches, no phone contact, no SHA-256 bypass.

## 12. Status and next actions

**PARTIALLY READY.**

Ready:
- The script, the repositories and the three tool versions (Java 8u292, Python 2.7.12, make 4.1) work on an Ubuntu 24.04 host.
- The host stays untouched.

Not yet established:
1. The same run on your WSL2 machine, including access to `/home/overm/android/`. Run the commands in section 8 and the probe in section 9.
2. A complete, documented package list (section 6).
3. Running as a normal user inside the chroot, and the GPG step being enforced in the script rather than by hand.

None of these blocks you. I did not change the script, so decide whether you want those fixes in a later step.

Test artefacts (the tarball, `xenial-root` and logs) are in this session's scratch folder, which disappears with the session.
