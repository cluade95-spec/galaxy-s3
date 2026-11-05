# Phase 8: SELinux back-port completion and runtime validation

Computer-only. No phone contact, nothing flashed, **the pinned kernel clone was never modified** (checked unchanged at the end: `44afe4cf…`, clean), SELinux was never disabled, no `allowxperm` rule was removed, the libGAL linker exception was not applied, the broad text-relocation flag is now switched off in `BoardConfig.mk`, and no ROM build was started.

Labels: **TESTED-QEMU** (observed in an emulator run, with logs), **COMPILED** (built, not run), **SOURCE**, **UNKNOWN**. All kernel runs are in QEMU's ARM Versatile Express board, not on the phone's hardware. Logs: [build-logs/phase8/](build-logs/phase8/).

## 1. Required report

| Question | Answer |
|---|---|
| Which binder hooks were missing? | All five LSM calls in `drivers/staging/android/binder.c`: `security_binder_set_context_mgr`, `security_binder_transaction`, `security_binder_transfer_binder` (called at two places, for local-node objects and for handle objects) and `security_binder_transfer_file`. The kernel also had no `binder` class in its SELinux class map (supplied by the Phase 7 back-port). |
| Were they ported correctly? | **Yes, for the behaviour tested.** Same five call sites and error handling as Google's android-3.4 (the added lines match). In QEMU each hook denies when the policy forbids and allows when it permits; a kernel without the calls lets every case through; a permissive run lets every case through. See section 4. |
| Did the experimental kernel compile? | Yes, three kernels (baseline, back-port without hooks, back-port with hooks) for the emulator board, with the pinned arm-eabi-4.6 compiler. The phone-board (PXA988) configuration with the back-port also compiled in Phase 7; it was not rebuilt with the binder patch in this phase (the binder driver compiled as part of the emulator build). |
| Did QEMU boot? | Yes: QEMU 8.2.2 `vexpress-a9`, Linux 3.4.5 built from our Samsung tree, a small initramfs, to the point of loading policy and running processes in other SELinux domains. |
| Did Android policy version 30 load? | **Yes.** The unmodified Android 7.1.2 policy (version 30, 184,107 bytes) was loaded by the back-ported kernel, and `policyvers` reads 30. **The same kernel without the back-port refuses it** with the kernel's own message `policydb version 30 does not match my version range 15-26` (error -22, `policyvers` 26). |
| Were extended permissions enforced? | **Yes, in enforcing mode, with the real Android rules.** `untrusted_app` may issue `SIOCGIFFLAGS`/`SIOCGIFINDEX` but gets `EACCES` for `SIOCGIFHWADDR` and `SIOCGIFMETRIC`; `priv_app` may issue `SIOCGIFHWADDR` (its own `allowxperm` rule) but not `SIOCGIFMETRIC`. A control domain with the same `ioctl` permission and no `allowxperm` rule may issue all of them. In permissive mode every denial disappears. Section 3. |
| What remains uncertain? | Section 7. |
| Is the libGAL exception safely scopeable? | **Scopeable, proven at compile and run time; not "safe" in an absolute sense.** Section 6. |
| What is still required before a full build? | Section 8. |

## 2. What was built and how it was run

| Piece | Detail |
|---|---|
| Emulator | `qemu-system-arm` 8.2.2 from Ubuntu 24.04 packages, downloaded with SHA-256 checks against the archive index and unpacked into a scratch folder (20 packages, 15 MB). **Nothing installed on the host.** |
| Kernels | Three separate copies of the pinned tree (`tools/selinux/qemu/make-qemu-kernels.sh`): **k0** = unchanged source with SELinux switched on; **k1** = + Google's android-3.4 SELinux/LSM code (the Phase 7 back-port, without the Android-M compatibility commit); **k2** = k1 + the five binder hook calls (`tools/selinux/patches/binder-lsm-hooks.patch`). The vexpress board needs three emulator-only adjustments, all **in the copies only**: Samsung's generic code includes `<mach/sec_debug.h>` (the same header is copied into the vexpress include folder), two Samsung symbols referenced from generic code get empty stand-ins (`sec_debug_check_crash_key`, `sec_class`), and `CONFIG_VIBRATOR_ANDROID` is off (it needs PXA988 headers). The configuration is `vexpress_defconfig` plus SELinux, audit, binder, devtmpfs. |
| Final patch | `tools/selinux/patches/android-3.4-selinux-backport.patch` (84 KB, 27 files, +1,387 / -139): the whole back-port as one patch, generated from the k2 copy. A check-only `git apply` onto the pinned clone succeeds; **it was not applied there**. |
| Policy | Android 7.1.2 policy as in Phase 7 (cm-14.1 `system/sepolicy` `83840c7f`, `vendor/cm`, host-built `checkpolicy` 30). Three images: the **unmodified** policy; the same plus a clearly marked test scaffold (`tools/selinux/qemu/gv_qemu_test.te`); and a scratch copy with the libGAL file-type proposal plus an execmod scaffold. The broad text-relocation flag is **off** in all of them. For test runs the `dontaudit` rules are stripped (`policy.conf.dontaudit`, the same variant Android's own build makes) so that every denial can be logged; allow rules are identical. |
| Harness | `tools/selinux/qemu/init.c`: a 40 KB freestanding ARM program that is `/init`. It mounts selinuxfs, loads the policy, switches child processes into other domains through `/proc/self/attr/current`, runs one operation per child, and reports through exit status. |
| What the scaffold adds (test only, nothing removed) | `permissive kernel` (the harness itself is not confined; every other domain is enforced); a few throw-away domains that differ in one permission; `sigchld` rules so the harness can reap children (without them `wait4` returns `EACCES`: a first run gave meaningless all-zero results because of this, which I caught and fixed before drawing any conclusion); `associate` rules for two test device nodes whose labels are set with `fscreate`. |
| Reproduce | `tools/selinux/qemu/README.md`; one command (`run-matrix.sh`) builds the policies and initramfs images and runs all nine runs. |

## 3. Results

Console logs: `01` to `09` in [build-logs/phase8/](build-logs/phase8/).

### 3.1 Policy loading (unmodified Android 7.1.2 policy, version 30)
| Run | Kernel | Result |
|---|---|---|
| 01 | k0: pinned source, SELinux on | **Load failed**, `SELinux: policydb version 30 does not match my version range 15-26`, write returns -22, `policyvers` = 26 |
| 02 | k1: back-port | **Loaded** (184,107 bytes), `policyvers` = 30 |
| 03 | k2: back-port + binder hooks | **Loaded**, `policyvers` = 30 |

### 3.2 Extended permissions (runs 04 and 05, enforcing; `socket` ioctls on a UDP socket in domains switched to with the real Android rules)
| Domain | ioctl | Rule in the Android policy | Result |
|---|---|---|---|
| `untrusted_app` | `SIOCGIFFLAGS`, `SIOCGIFINDEX` | in `unpriv_sock_ioctls` | allowed (0) |
| `untrusted_app` | `SIOCGIFHWADDR`, `SIOCGIFMETRIC` | in `priv_sock_ioctls`, `neverallowxperm` | **denied, `EACCES`** |
| `priv_app` | `SIOCGIFHWADDR` | its own `allowxperm` rule | allowed |
| `priv_app` | `SIOCGIFMETRIC` | priv list | **denied** |
| `gv_noxperm` (control: `ioctl` allowed, no `allowxperm`) | both | none | both allowed |
Run 07 (same kernel, permissive): the three denials turn into success. So the denials are SELinux's, and they come from the per-command (extended permission) filter, not from the plain `ioctl` permission.

### 3.3 Binder hooks (a servicemanager-domain process is the context manager)
| Case | k1 (no hook calls) | k2 (hook calls) |
|---|---|---|
| 5 `set_context_mgr` from `priv_app` (policy forbids) | succeeds | **denied (`EACCES`)** |
| 5 `set_context_mgr` from `servicemanager` (policy allows) | succeeds | succeeds |
| 1 transaction from a domain without `binder:call` | delivered | **`BR_FAILED_REPLY`** |
| 1 transaction from a domain with `call`; and from `priv_app` (real policy) | delivered | delivered |
| 2 object transfer, local node (`BINDER` type), without `binder:transfer` | delivered | **`BR_FAILED_REPLY`** |
| 3 object transfer, handle (`HANDLE` type), without `binder:transfer` | delivered | **`BR_FAILED_REPLY`** |
| 4 file-descriptor transfer to a node that accepts descriptors, receiver without `fd:use` | delivered | **`BR_FAILED_REPLY`** |
| the matching cases with the permission present | delivered | delivered |
Hook numbers used in the first column: 1 = `security_binder_transaction`, 2 = `security_binder_transfer_binder` for a local-node object, 3 = the same call for a handle object, 4 = `security_binder_transfer_file`, 5 = `security_binder_set_context_mgr`. Run 04 (k1 against the "no hooks" expectation) passes 19 of 19; run 05 (k2 against the "hooks" expectation) passes 19 of 19; run 06 (k1 judged against the "hooks" expectation) fails **exactly the five denial cases** (14 of 19), which shows the harness can tell the difference; run 07 (k2 permissive) passes 11 of 19, all eight failures being denials that no longer happen.

### 3.4 Not seen
No kernel oops or panic in any run. **No `avc: denied` audit record appeared in the console for the extended-permission or execmod denials**, although other denials were logged. I did not find out why (candidates: audit rate-limiting or the audit path for these two denial types). The denials are established by the `EACCES` results, the allowed controls and the permissive-mode controls, not by audit lines.

## 4. Were the hooks ported correctly? (detail)
- Sites: before the one-way/reply logic in `binder_transaction` (transaction), before `binder_get_ref_for_node` and before the `ref->node->proc == target_proc` test (transfer_binder, both object kinds), after `fget` and before the target descriptor is allocated (transfer_file, with `fput` and the existing error label), and in the `BINDER_SET_CONTEXT_MGR` case before the user-id test. These are the same places and error labels as Google's; the added text is identical (compared automatically).
- Samsung's `binder.c` differs from Google's by about 50 lines; only the hook calls were taken. The others are unrelated: for example Google's version has a fix to `binder_proc_show` (it validates the process pointer before use) and uses freezable waits. Those are worth a separate review; they were not ported and are not part of this claim.
- Tested at run time: all five hook calls, individually, in both directions (section 3.3).
- Not tested: more than one binder thread per process, real service-manager traffic, death notifications, binder over a long run.

## 5. Why a few test results were wrong before they were right
Recorded because it affects how far to trust the rest:
1. First run: every child result was `0`. Cause: `wait4` itself was failing with `EACCES` (SELinux checks `sigchld` from child to parent) and the harness read an unset status. Fixed by checking the `wait4` return value and by adding the `sigchld` allow rule to the scaffold. No result from that run is used.
2. Second run: sockets failed with `EACCES`. Cause: the kernel's `ANDROID_PARANOID_NETWORK` lets a process create sockets only if it is in group 3003 (or has `CAP_NET_RAW`, which `untrusted_app` is denied). Fixed by joining group 3003 before the domain switch, as zygote does for apps.
3. `/dev/binder` appeared labelled `device`, which the policy does not allow; the harness creates its own nodes with the expected types using `fscreate`.
4. File-descriptor transfer to the context manager always fails before the hook (the context manager's node does not accept descriptors); the descriptor case therefore uses a second process that publishes a node flagged to accept them.

## 6. libGAL file type: review of the proposed design (not applied)

Proposal files: `android/device/samsung/goldenvess3g/sepolicy/proposals/` (`libgal_file.te`, `guards/libgal_file_guards.te`, `file_contexts.libgal`, `domain-te-libgal-type.patch`) and revision 2 of `patches/bionic-libGAL-textrel.patch`. Nothing is wired into a build. Compile logs: [10](build-logs/phase8/10-libgal-type-policy-compile.log), runtime logs: 08 and 09.

### What it is
A new file type `libgal_file` (`exec_type`), assigned to exactly `/system/lib/libGAL.so`, and `execmod` granted on that type, instead of on all of `system_file`.

### Policy compile results (checkpolicy 30, scratch copies)
| Case | Result |
|---|---|
| C1/C2 stock `domain.te`, flag off or on, dedicated type | **Fails**: the platform's `neverallow` forbids `execmod` on any new file type. So the exception **is needed**. |
| C3 patched `domain.te` (one type added to three exemption lists, 4 added or changed lines), flag **off** | **Compiles.** The broad text-relocation flag is not needed for the policy. |
| C4 patched, plus guard assertions, plus deliberate wrong grants to `system_server` and `bluetooth` | **Rejected** by the guard assertions (2 failures). |
| C4b patched + guards, no wrong grants | Compiles. |
| C5 patched, **no** guards, wrong grants | **Compiles**: the exemption alone does not restrict who gets `execmod`. The guards are part of the proposal, not optional. |
| C6 broad alternative (`execmod` on `system_file`) | Compiles only with the flag **on**; with the flag off the same rules are rejected. |
Two details found on the way: `appdomain` includes `shell`, `bluetooth`, `radio`, `shared_relro` and others, so the proposal names `untrusted_app platform_app system_app priv_app` instead; and a new file type needs the `exec_type` attribute, which also brings the platform's "no domain may write an exec_type file" assertions.

### Run-time results in QEMU (policy semantics, run 08)
A domain granted `execmod` on `libgal_file` completes the text-relocation-like sequence (map a library file private and writable, modify a page, make it executable) on a file labelled `libgal_file`; a domain without that grant is refused (`EACCES`); a domain **with** the grant is refused for a differently labelled file. With SELinux permissive (run 09) all three succeed. So the grant is limited by **target type** at run time, not only at compile time.

### Is the neverallow exception defensible?
- It adds one type to exemption lists that already contain `system_data_file`, `apk_data_file`, `app_data_file` and `asec_public_file` (and `system_file` under the flag): a much smaller exemption than the ones AOSP already carries.
- It shrinks what the project needs: with it, `execmod` is limited to one library file instead of every file labelled `system_file`, and the broad flag stays off.
- It needs a patch to a platform file (`system/sepolicy domain.te`) that must be carried on every sync, and it only works together with guard assertions (C5).
- Defensible **if**: only that one type is exempted; the guards ship with it; the type labels exactly one path; `/system` is read-only; the owner signs it off.

### Safely scopeable? Limits that remain
- Scoping by file and by domain list works (proved). It does not change what `execmod` means: in a process that holds it, code can be placed in the modified pages of that mapping and executed. For `surfaceflinger`, `mediaserver` and `bootanim`, which have no `execmem` rule, that is a **new code-injection primitive** limited to that library's pages; for apps (already `execmem`) the increase is small.
- Any domain that loads `libGAL` and is **not** in the list fails closed with a denial (good for review, bad for a first boot). Which domains really load it is only known from the dependency graph of the community dump (UNKNOWN until a boot).
- The linker side must also let the library through. Revision 2 of the exact-path patch covers the case where the broad flag is off; it applies cleanly to cm-14.1 bionic (check only, [11](build-logs/phase8/11-libGAL-patch-rev2-check.log)). **With the broad flag off, every other text-relocation library (GPS, `libgpucsc`, `libacdapi_clb`, the codecs, the modem libraries) is refused by the linker.** The first-build scope must either omit them or give each its own reviewed exception.
- Memory: 464 KiB of private text per process that maps `libGAL` (Phase 7 measurement).

Verdict: **safely scopeable in the sense that the grant can be confined to one file, a named domain list and a compile-time guard; still a real weakening that needs your explicit decision.** Not applied.

## 7. What remains uncertain
- Everything here ran in an emulator with a generic board. The phone's PXA988 board, its drivers and Samsung's own changes were not exercised. The PXA988-configuration kernel with the final patch was compiled in Phase 7 (without the binder patch) and not run.
- No real Android userspace ran: no `init`, no real service manager, no file labelling from `file_contexts`, no ext4 labels (the harness labels nodes with `fscreate`).
- The two Samsung-only symbols and header were stubbed in the emulator copies; they are irrelevant on the emulated board but unknown on the phone.
- No audit records for xperm and execmod denials (section 3.4).
- Stability, performance and long-running behaviour of the extended-permission cache are untested.
- `no_new_privs` is absent in this kernel (the back-port defines the constant but nothing sets it).
- The libGAL proposal is untested against the real library, because no official firmware exists; which domains load it is unconfirmed.
- Several of Google's other binder fixes are not ported (section 4).
- The policy has no device-specific rules yet; a real device adds rules and denials.

## 8. What is still required before a full build
1. **Official firmware and partition data** (unchanged from Phase 7, Part D): the official kernel package, the firmware with hashes, the boot image header values, the partition table. Nothing else unblocks the vendor tree, the boot image or the guards.
2. **Your decisions**: adopt the SELinux back-port as a carried kernel patch series (the patch file is ready; the Koloses source stays untouched); the libGAL design (dedicated type plus `domain.te` exemption plus guards, or the broad alternative, or neither); whether the first build accepts the other text-relocation libraries being refused.
3. **A phone-board kernel** built from the pinned source plus the patch, with the SELinux options, and its modules, in the out-of-band directory the build guards expect. (Not built in this phase.)
4. **A build host** with the userland and disk from Phase 7 (setup instructions: section 9).
5. Optional but recommended: review the unrelated binder fixes; find out why no audit records appeared.

## 9. Isolated Ubuntu 16.04 build environment: reproducible setup (review)
Script: `tools/build/xenial-userland.sh` (sub-commands `fetch`, `extract`, `install`, `enter`, `teardown`). It changes **no host package**; root is needed only for `chroot` and `mount`.

| Step | What it does | Tested here? |
|---|---|---|
| `fetch DIR` | Downloads `ubuntu-base-16.04.6-base-amd64.tar.gz` and `SHA256SUMS`, verifies the SHA-256, and prints the `gpg --verify` command you must also run. | **Yes** (`OK`, [12](build-logs/phase8/12-xenial-userland-script-test.log)) |
| `extract DIR` | Unpacks to `DIR/xenial-root`; refuses to overwrite. | Equivalent steps done by hand in Phase 7 |
| `install DIR` | Writes `sources.list` (archive, updates, security), mounts `/proc`, runs `apt-get install` of the Android 7 build packages and links `python` to `python2.7`, then prints Java, Python and make versions. The package list is the AOSP 7.x Ubuntu 16.04 list **from memory of that page** plus Python 2: check it against the LineageOS 14.1 documentation. | **No**: this sandbox's proxy rejects some `apt` requests and blocks `security.ubuntu.com`. Python 2.7, OpenJDK 8 and make 4.1 were installed by fetching the packages with `curl` (Phase 7). |
| `enter DIR [SRC] [CMD...]` | Bind-mounts `/proc`, `/dev` and, if given, your source tree at `/src`; runs the command in the chroot with a clean environment; unmounts on exit. | **Yes**: Python 2.7.11, make 4.1 and `openjdk 1.8.0_03` ran inside; no mounts left afterwards |
| `teardown DIR` | Unmounts anything left; refuses if mounts remain; prints (does not run) the single `rm -rf` to delete the folder. | **Yes** |

Review notes:
- **Reproducibility:** the base tarball is pinned by name and hash; packages follow whatever the archive serves on the day. For exact repeats, record `dpkg -l` output after `install` and keep the `.deb` files. Not done here.
- **`repo` and git run on the host** (the 16.04 userland has Python 3.5, too old for `repo`); build inside the chroot with the tree bind-mounted. The Phase 6 driver needs a small split for that and is not changed.
- If your ThinkPad runs Ubuntu under WSL2 the same steps apply inside the Linux filesystem; chroot under WSL2 was not tested.
- **Not isolated from the kernel:** a chroot shares the host kernel and network. For stronger isolation use a VM or a container engine you already have; not tested here.
- Remove with `teardown` then the printed `rm -rf` (unmount first; never remove a tree that is still bind-mounted).

## 10. Limitations of this document
All results are from an emulator and from compile-time policy checks on a scratch copy; nothing is a statement about the phone, and none of it proves that a ROM boots or that any hardware works.
