# Phase 10: audit of `tools/build/xenial-userland.sh` for a WSL2 Ubuntu 24.04 host (revision 2)

**Status: proposal and test evidence only. Nothing was run on your machine, nothing is committed or pushed, and the script is NOT claimed ready for real WSL2 use** (section 8 lists what is still open).
The original `tools/build/xenial-userland.sh` is unchanged (SHA-256 `a70ecc8b…b90fc`). The proposal is `tools/build/xenial-userland.v2.sh`.

| Revision | File | SHA-256 |
|---|---|---|
| rev 1 (reviewed earlier, superseded) | `xenial-userland.v2.sh` | `6eee09dea0e49387fb3534cbb18ac0fe84536caf66154502bf581c6091dd492d` |
| **rev 2 (this document)** | `tools/build/xenial-userland.v2.sh` (469 lines) | see the final report; `sha256sum` it yourself |

Review diffs: `tools/build/xenial-userland.sh.to-v2.diff` (original to rev 2) and `tools/build/xenial-userland.v2-rev1-to-rev2.diff` (what changed since you last saw it).

Rules kept: no Android source download; `fetch`/`extract`/`install` never run on your machine; no `sudo` there; no system configuration changed; no phone; no commit or push.
Test environment: this sandbox (Ubuntu 24.04.5 container, kernel 6.18, running as root). It is **not WSL2**. All mount tests ran in a private mount namespace (`unshare -m`). No Ubuntu image was downloaded: the Phase 7 tarball already on disk was used where marked.

Labels: **EXECUTED** (run here, output in `docs/build-logs/phase10-rev2/`), **THEORETICAL** (reasoned or read, not run), **UNRESOLVED**.

## 1. What was wrong (original script, and rev 1)

| # | Severity | Finding | Basis |
|---|---|---|---|
| F1 | High | Original `fetch`: hash from a same-origin plain-HTTP `SHA256SUMS`; the signature was never verified (`|| true`). | read |
| F2 | High | Original `enter` runs as root; files in `/src` become root-owned. | EXECUTED (contrast test O11) |
| F3 | High | Original `teardown` with a relative `ROOT_PARENT` reported "no mounts remain, run rm -rf" while 3 mounts, including the source tree, were live. | EXECUTED (C1) |
| F4 | High | **rev 1: a path with a space made the mount checks blind.** `mounted`, `any_mount_below` passed the escaped path to `awk -v`, which turns `\040` back into a space; `enter` then returned 0 and left 3 mounts behind. | EXECUTED on rev 1 (experiment B); fixed and tested (W1, W2) |
| F5 | High | **rev 1: SIGTERM is deferred while the session program runs.** bash does not run a trap while a foreground command is running; after `kill -TERM` the script and the program kept running for as long as the program did. | EXECUTED on rev 1 (experiment A: still running after 3 s, exit 143 only when the program ended); fixed (S1, S5) |
| F6 | High | rev 1 `install` trapped INT/TERM/HUP with a handler that did not exit, so execution can resume after the trap. In my test the foreground `apt` also received SIGINT and `set -e` stopped the script, so **I could not reproduce an actual continuation on rev 1**; it is a design flaw shown by reading, and mutant B (section 6) checks that the new tests would catch it. | read; mutant test |
| F7 | High | `install` ran as root with the host's whole `/dev` bind-mounted (including disk devices) and the tarball's 79 device nodes were created on disk. | read; EXECUTED fix (E2, X7, X8) |
| F8 | Medium | Symlinks were followed when root wrote files in the userland (`resolv.conf`, `sources.list`, `policy-rc.d`, `passwd`, `group`) and when it ran `chown` on `home/builder`. | EXECUTED fix (Y1 to Y8) |
| F9 | Medium | An interrupted or failed `extract` left a partial tree. | EXECUTED fix (E10) |
| F10 | Medium | No guard for `/mnt/c`, `noexec` filesystems, odd characters in paths, low disk space, concurrent runs. | EXECUTED fixes (R10, R11, W3 to W5, T5b) |
| F11 | Medium | Original package list incomplete; rev 1's list was derived from the 2018 wiki page, not the file you named. | section 4 |

## 2. Teardown: refuse BEFORE unmounting anything (request item 1)

`teardown` now does, in this order:

1. If `ROOT` does not exist: say so, exit 0.
2. `chroot_pids`: any process whose root is inside the chroot, **or whose current directory is inside it** (a host shell that did `cd` there).
3. If any: print each pid and program, exit **4**, and **unmount nothing**. The message tells you how to leave safely: exit the shell in each `enter` terminal (it then unmounts by itself), stop background programs started inside (for example the Jack server of a 14.1 tree), `cd` out of the chroot from host shells, run teardown again; teardown never kills processes; a stuck process you stop yourself.
4. Only then: take the lock, unmount everything below `ROOT` deepest first (read from `/proc/mounts`, with correct escaping), verify none remain, print the `rm -rf --one-file-system` hint.

`umount_chroot` repeats the process check (defence in depth), so no code path unmounts while the chroot is in use.
EXECUTED (T1 to T10): with a live session, teardown exits 4, the mount count is unchanged (11 before and after), the message names the pid and program and gives the exit instructions; a host process sitting in `$ROOT/tmp` also blocks it; after the session ends teardown succeeds; a missing userland is harmless.

## 3. Interruption: traps and cleanup (request item 3)

Design, as implemented:

| Situation | Behaviour | Evidence |
|---|---|---|
| `enter`, TERM / HUP / QUIT | handler stops the session (TERM to the child, then to everything whose root is inside the chroot, KILL after 8 s), unmounts, exits 143/129/131 | EXECUTED S1 |
| `enter`, a program that ignores TERM and HUP | killed after the grace period; mounts removed | EXECUTED S5 (9 s) |
| `enter`, Ctrl-C | the terminal delivers INT to the whole foreground group; the program inside handles it; the script **ignores INT while waiting** (so Ctrl-C at an interactive shell prompt does not end the session) and cleans up after the session command exits | EXECUTED S2 (group INT: exit 130, mounts removed) |
| `enter`, INT sent only to the script (`kill -INT PID`, no terminal) | ignored: session keeps running; TERM still stops it | EXECUTED S3, S4 |
| `install` / `extract` / `fetch`, INT / TERM / HUP / QUIT | abort immediately: child killed, nothing further runs (the next install steps are skipped), partial files removed, mounts removed, exit 128+N | EXECUTED D1 (install), E10 (extract), F7 (fetch) |
| a mount fails half-way (calls 2, 5, 11 of the mount sequence) | script stops; every mount made so far is removed | EXECUTED M1 (a `mount` wrapper fails the Nth call) |
| the session shell exits but a program is still running inside | **exit 3, mounts kept in place** (no partial unmount while it runs), program reported; `enter --kill-leftovers` stops it instead | EXECUTED L1 to L8 |
| apt step fails | install stops with a message, kills what remains in the chroot, unmounts | EXECUTED D2 |

How it works: the session command runs in the background and the script `wait`s, so a trapped signal acts at once. The `EXIT` trap is idempotent and does the kill, the unmount, and the removal of partial files. Every signal handler ends in `exit`. Commands run through `run_child`, with an `env --default-signal=INT,QUIT` prefix for `enter` (a background job otherwise starts with SIGINT ignored, and Ctrl-C would not reach the programs inside).

**Known limits (THEORETICAL or documented, not fixed):** SIGKILL, a crash or a power loss cannot run any trap and leaves mounts: `teardown` is the safe recovery. A script started with SIGINT/SIGQUIT already ignored (a `nohup` or background job) cannot trap them (this bit my own test harness once; run the script in the foreground). SIGTSTP (Ctrl-Z) is not handled. A TERM during `dpkg` can leave half-configured packages (the message says how to recover).

## 4. Package list vs the authoritative file (request item 2)

**Authoritative source, as you directed:** `LineageOS/lineage_wiki`, `_includes/templates/device_build_before_init.md`, commit `504b1dbb` (2026-10-20). The file first appears in 2020 (commit `6e24e586`) and is written for current branches; the same page for the 14.1 era was `device_build.md` (the 2018 revision `d8faa0c0`, which rev 1 used). So for 14.1 this is the best available authoritative list, not a 14.1-era one. Whether every entry matters for a 14.1 tree is UNRESOLVED (no source tree, no build).

The complete row-by-row comparison with reasons is `docs/data/package-decisions.tsv` (60 rows); Xenial availability of every name is `docs/data/xenial-package-availability.tsv` (indexes of xenial, -updates and -security, main and universe, plus the Xenial `Contents` index for file ownership; EXECUTED 2026-11-06). Summary:

**Installed unchanged (authoritative list ∩ Xenial):** `bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick kmod protobuf-compiler lib32z1-dev libdw-dev libelf-dev libgnutls28-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev`. Five of them (`kmod protobuf-compiler libdw-dev libelf-dev libgnutls28-dev`) were added to the wiki for newer branches (the commit ids are in the TSV); they are installed because the list is authoritative and they exist in Xenial, and whether 14.1 needs them is UNVERIFIED. **`ccache` moved from optional (rev 1) to default**, because it is in the list.

**Renamed for Xenial:**

| Authoritative name | Installed as | Reason (EXECUTED lookups) |
|---|---|---|
| `lib32readline-dev` | `lib32readline6-dev` | virtual name in Xenial, one provider |
| `lz4` | `liblz4-tool` | no `lz4` package; `/usr/bin/lz4` belongs to `liblz4-tool` (Xenial Contents) |
| `xxd` | `vim-common` | no `xxd` package; `/usr/bin/xxd` belongs to `vim-common` (Xenial Contents) |
| `python-is-python2` (14.1 section) | `python2.7` + `/usr/bin/python` link made by the script | `python-is-python2` is a 20.04+ package |

**In the list but NOT in Xenial, therefore omitted:** `erofs-utils` (added 2026-08-19 for EROFS images of recent branches), `git-lfs` (added 2023-03 for WebView, LineageOS 20+), `python3-protobuf` (added 2025-04 with `protobuf-compiler`). None is documented as a 14.1 requirement; UNVERIFIED for this tree. If a real build asks for one, the options are a newer userland (Ubuntu 18.04/20.04) or a specific package build; that is a decision for you.

**Omitted by the list itself for 14.1:** `yasm` (x86 targets only; this device is ARMv7), `maven` (13.0 only), `libwxgtk2.8-dev` (Ubuntu older than 16.04), `libxml2-16` (Ubuntu 26.04+), `libtinfo5` manual `.deb` (Ubuntu 23.10+), `openjdk-7-jdk` (11.0 to 13.0).

**14.1 conditional lines, installed:** `lib32ncurses5-dev libncurses5 libncurses5-dev` (Ubuntu older than 23.10), `libwxgtk3.0-dev` (older than 20.04), `openjdk-8-jdk`.

**Extra (not in the authoritative list), with reasons:** `libc6-dev-i386 x11proto-core-dev libx11-dev libgl1-mesa-dev unzip` (AOSP Nougat's Ubuntu list), `make` and `ca-certificates` (a minimal chroot needs them explicitly). Optional (`INSTALL_OPTIONAL=1`): `python-networkx` (AOSP: SELinux policy analysis only) and `libesd0-dev` (in the 2018 page, dropped from the current one: obsolete; **removed from the default set**). Replaced: AOSP's `git-core` by `git`, `lib32z-dev` by `lib32z1-dev`; `liblz4-tool` (also in the 2018 list) is kept only as the Xenial home of `lz4`.

**New requirement found in the file:** for LineageOS 14.1-15.1 the page says to remove `TLSv1` and `TLSv1.1` from `jdk.tls.disabledAlgorithms` in `/etc/java-8-openjdk/security/java.security`. Rev 2 does this after the install, inside the chroot only, keeps the original as `java.security.orig-xenial-userland`, refuses to follow symlinks, **fails closed** if the file layout is not the expected one (for example a token last on its line), and can be skipped with `KEEP_JAVA_TLS_DEFAULTS=1`. This lowers the TLS floor of Java inside the build chroot (the page's requirement, not mine). EXECUTED only on mock files in the 8u292 layout (J1 to J14); the real 8u292 file has not been seen (UNRESOLVED).

**Python:** the file also tells you how to run Python 2 for 11.0-16.0; on Xenial the script's `python2.7` + link does the same job.

## 5. Other safety and correctness changes (request item 4)

- **Minimal private `/dev`** instead of the host's: a tmpfs with only `null zero full random urandom tty` (bind-mounted), `pts`, `shm`, `ptmx`, `fd`, `stdin/out/err`. EXECUTED on the real Ubuntu 16.04 userland: `ls /dev` is exactly that set, no host disk visible, `/dev/null`, `/dev/urandom` and `<(...)` work (X6 to X8). Device nodes are no longer extracted at all (E2, E3).
- **Root tree checks:** `ROOT` and `proc dev etc etc/apt home tmp usr usr/sbin var var/log` must be real directories (no symlinks), `ROOT` owned by root; `passwd`/`group` regular files; `home/builder` not a symlink; all files written as root replace a symlink instead of following it; `chown -h`. The real extracted tarball passes the check (E6).
- **Mount handling:** every mount below `ROOT` is read from `/proc/mounts` and removed deepest-first; escaped paths go through `ENVIRON`, not `awk -v` (F4); no lazy unmount; failures block `teardown`.
- **Path validation:** newline, tab, carriage return, backslash refused; `/mnt/<drive>` and 9p/drvfs/ntfs/fuseblk/cifs/vfat filesystems refused; `noexec` userland filesystem refused; `SRC` must be an existing directory owned by the target uid, not `/`, `/home`, `/root`, system directories, or inside the userland directory. Spaces in paths work (W1, W2).
- **Ownership:** the script never runs `chown` on `SRC`; builder uid/gid are collision-checked; `--root` is explicit and warns.
- **Concurrency:** one instance per `ROOT_PARENT` (`flock`, not inherited by the session); a second `enter` is refused (T5b, L5). **`extract` takes the same lock before it looks at `$ROOT`** and holds it through its cleanup, so a concurrent extract is refused and can never remove the other's partial tree (E11 to E13; added after review).
- **Failure cleanup:** the EXIT trap removes the download temp directory, a partial extraction, and all mounts; partial extraction tested (E10).
- **Disk space checks** for fetch (4 GiB), extract (1 GiB), install (3 GiB); thresholds are estimates.
- **Extract** skips everything below `dev/`; install writes `policy-rc.d` (exit 101) so package scripts cannot start services, mounts only the chroot (not `SRC`) while root runs apt, and records installed versions in `xenial-userland-installed.list`.
- Unchanged from rev 1 and EXECUTED again: the signature chain (pinned fingerprint `843938DF228D22F7B3742BC0D94AA3F0EFE21092`, keyring provenance, pinned tarball hash), tar listing check.

## 6. Tests (request item 5)

**EXECUTED, all passing** (logs: `docs/build-logs/phase10-rev2/offline.log` and `root.log`):

| Suite | Needs | Result |
|---|---|---|
| `test-verify.sh` (signatures, impostor/expired keys, tar listing) | none | 26 / 26 |
| `test-packages.sh` (lists vs authoritative file, decisions table, Xenial data) | none | 43 / 43 |
| `test-java-tls.sh` (mock `java.security`) | none | 14 / 14 |
| `test-fetch.sh` (real `cmd_fetch`, fake `download`; refusals; INT/TERM/HUP/QUIT mid-download) | none (real tarball used only if on disk) | 13 / 13 |
| `test-enter-ownership.sh` (ownership, privilege drop, refusals) | root | 21 / 21 |
| `test-session-safety.sh` (**live process during teardown**, signals in enter and install, leftovers, lock, mount failures, symlink attacks, odd paths, noexec, original-script contrast) | root | 53 / 53 |
| `test-extract-real.sh` (real tarball: extract, interrupted extract, **`enter`/`teardown` on the real Ubuntu 16.04 userland**) | root + real tarball | 23 / 23 |

That is 193 checks, 0 failures (96 without root, 97 with root). The root suites run in a private mount namespace on a tiny chroot (bash and coreutils copied from this host), except `test-extract-real.sh`, which uses the real Xenial base image (no `apt`).
The logs contain the final run of the unchanged rev-2 script, including the lock checks T5b/T5c.

**Mutation checks (are the new tests able to fail?)** EXECUTED against scratch copies of the script, not against the file you review:
- Mutant A, teardown without the live-process check: the suite fails 5 checks (T1, T3, T4, T8, L4).
- Mutant B, signal handlers that return instead of exiting: the suite reports wrong exit statuses (S1 HUP and S1 QUIT got 143) and then hangs until its 290 s timeout (rc=124), because the signalled scripts never end.

**NOT executed (THEORETICAL):**
- `install` end to end: the real `apt-get update` and `apt-get install` (only a stand-in `apt-get` was used), dependency resolution with `--no-install-recommends`, the real `java -version`/`python --version` checks, the TLS edit on the real file.
- `fetch` over the real network (the HTTPS download itself; the verification and refusal logic around it was executed).
- Anything on WSL2: its kernel, its `/mnt` handling and filesystem type names, `sudo` on your Ubuntu, systemd and mount propagation (tests used a private namespace; a real run uses the shared one).
- A real terminal: Ctrl-C was simulated by a process-group signal, an interactive `bash` in the chroot with a real pty (devpts) was not used, Ctrl-Z was not tested.
- Two terminals at once beyond the lock test; low-disk behaviour; SIGKILL recovery by hand.
- A full LineageOS 14.1 build with these packages and versions.

## 7. What you can run on your machine without root

`bash tools/build/test/run-offline-tests.sh` (no root, no network, no image download). Root tests: `sudo tools/build/test/run-root-tests.sh`; each re-executes itself in a private mount namespace.

## 8. Limitations that remain: the script is NOT declared ready for real WSL2 use

1. Never executed on WSL2. Kernel, filesystem-type names (`9p`/`drvfs`), mount propagation and `/dev` handling there are untested.
2. `install` never ran against the real archive. Xenial is past standard support; the public archive is frozen; a missing or changed package fails the install (with cleanup), not silently.
3. The authoritative package file is a modern one. Three packages from it do not exist in Xenial (omitted, section 4); the list's fitness for 14.1 is unverified until a build runs.
4. The TLS relaxation is a security setting inside the chroot, required by the wiki, tested only on mock files.
5. Signal behaviour was tested with simulated signals, not a real terminal session; SIGKILL, crash and power loss leave mounts (use `teardown`).
6. Leftover background programs (the Jack server) keep the mounts and give exit code 3 unless `--kill-leftovers` is used.
7. A chroot is not a security boundary: root inside it (during `install`) shares your kernel, network and process table; it no longer sees your disk devices or your source tree.
8. `dpkg --verify` (keyring provenance) detects accidental or naive changes, not a root attacker; the pinned fingerprint still needs your own comparison with a source you trust.
9. Checks are made before mounts, not atomically; the directory holding the userland is expected to be yours alone.
10. All test results come from one Linux container as root.

**Recommendation:** the **original script remains NO-GO**. Rev 2 is a better candidate and the open items above are documented, but I do **not** call it ready. A sensible next step on your side is to read the diffs, run the no-root offline tests, then (still without installing) run `fetch` only; I would not run `install` until you accept limitations 1 and 2.
