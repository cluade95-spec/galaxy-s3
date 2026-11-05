# Phase 7, Parts A and B: SELinux compatibility and the libGAL security review

Computer-only. No phone contact, nothing flashed, SELinux not disabled, **the pinned kernel clone was never modified** (all kernel experiments ran in separate copies that were deleted afterwards), the libGAL exception was not applied, no policy rule was removed or edited, and no ROM build was started.

Evidence labels: **SOURCE** (read in sources), **TESTED-HOST** (ran on this computer), **COMPILED** (compiled, never run), **UNKNOWN**. Policy sources: LineageOS cm-14.1 `system/sepolicy` at `83840c7f` and `vendor/cm/sepolicy` at `3747219d`. Kernel: Koloses `kernel_i8200` at `44afe4cf…` (Linux 3.4.5). Logs: [build-logs/phase7/](build-logs/phase7/). Exact revisions of everything used: section 9.

## 1. Summary of findings (final report)

| Question | Answer |
|---|---|
| Is a safe SELinux back-port technically feasible? | **Yes, on paper and at compile level; not yet proven at run time.** Google published exactly this back-port for Linux 3.4 (`kernel/common`, branch `deprecated/android-3.4`). Applying it to a separate copy of our Samsung kernel gave a kernel that **compiles** with SELinux enabled and the extended-permission code present. No kernel was run, so loading and enforcing the Android 7 policy is **UNPROVEN**. |
| What kernel changes would be required? | (1) Kernel configuration: `SECURITY`, `SECURITY_NETWORK`, `AUDIT`, `SECURITY_SELINUX`, `SECURITY_SELINUX_DEVELOP`, `EXT4_FS_SECURITY`, default security SELinux. (2) Source: bring `security/selinux` and the small Linux Security Module glue up to the state of Google's android-3.4 (policy formats 27 to 30, ioctl extended permissions): about 26 files, +1,366 / -139 lines, all under `security/` and two headers. (3) Five LSM call sites in the Android binder driver so binder is mediated. (4) Runtime verification. None of this is applied to the production tree. |
| Can the Android 7 policy compile without disabling security? | **At version 30: yes, with no errors** (TESTED-HOST, 21,473-line policy, 144 inputs). **At versions 26 to 29 (what the unmodified kernel could load): no.** Exactly one error each: the policy contains 5 `allowxperm` rules, which need version 30. The only way to make it compile at 26 is to delete those rules, and they *narrow* access, so deleting them **widens** it. That is the stripping you ruled out, so I did not do it. |
| Is the libGAL exception acceptable? | **Conditionally, for an experimental, non-daily-use build only; not as a product default.** The linker part (one exact path) is small. The cost is the SELinux `execmod` grant it needs, which is a code-injection-class permission. Acceptable only if scoped as in section 7 and approved by you. |
| Build environment | Ubuntu **16.04 userland** (OpenJDK 8, Python 2.7, make 4.1) in a chroot or container on the Ubuntu 24.04 host; run `repo` on the host. See [phase-7-build-environment-and-firmware.md](phase-7-build-environment-and-firmware.md). |
| Disk to reserve | **200 GiB free minimum, 250 GiB recommended** (estimate, section 2 of that document). |
| Before Phase 8 | See section 8. |
| **Recommendation** | **GO for a Phase 8 limited to computer-only preparation. NO-GO for any hardware test or flashing, and NO-GO for a full ROM build until official firmware and the real partition data exist.** Details in section 8. |

## 2. What the kernel has today (Part A, items 1 and 2)

| Item | Finding | Evidence |
|---|---|---|
| Kernel | Linux 3.4.5, source `Koloses/kernel_i8200` @ `44afe4cf…`, `security/selinux` present | SOURCE |
| Config | `CONFIG_SECURITY` unset, so `AUDIT`, `SECURITY_SELINUX` and `EXT4_FS_SECURITY` are all off | the Phase 2 generated `.config` |
| Policy versions the kernel understands | 15 to **26** (`POLICYDB_VERSION_ROLETRANS`) | `security/selinux/include/security.h` |
| Extended permissions (`xperm`) | **0 occurrences** in `security/selinux` | grep |
| Binder hooks | `security_binder_*` not called in `drivers/staging/android/binder.c`; no `binder` class in the kernel's class map | grep |
| Samsung changes in the files that matter | None found in `security/` or the two LSM headers (no `samsung`, `SEC_`, `knox` strings), so replacing them discards no vendor code | grep |
| Class and permission fit with the Android 7 policy | Every kernel class and permission exists in the policy (parsed from `policy.conf`). The policy has 14 classes the kernel does not know: `binder` plus 13 others. 5 of those are userspace-only (`debuggerd`, `drmservice`, `keystore_key`, `property_service`, `service_manager`); 8 are netlink families (`netlink_connector_socket` and others) that Google's own android-3.4 does not know either. | TESTED-HOST |

What Android 7.1.2 needs from the kernel:
1. **SELinux in the kernel.** Android 7's init loads the policy and aborts through `security_failure()` if loading fails (`system/core/init/init.cpp`, SOURCE). Even "permissive" mode needs the kernel code.
2. **Policy format version 30.** `POLICYVERS ?= 30` in `system/sepolicy/Android.mk` (SOURCE). Versions: 27 = default user/role/range, 28 = `default_type`, 29 = constraint names, 30 = ioctl extended permissions (`libsepol` header in AOSP `external/selinux`, SOURCE). The kernel has to read the on-disk format of 27 to 29 even if the policy does not use those features, because the class records changed; the policy language features themselves are optional.
3. **Ioctl extended permissions**: used by 5 rules (below).
4. File labels: `EXT4_FS_SECURITY`, plus per-file labelling for sysfs and debugfs paths used by the policy's `genfscon` lines.

## 3. The smallest technically correct back-port (items 3 and 4)

Upstream references (no invented IDs; each is quoted from the commit text in Google's branch):

| Step | Policy version | Mainline commit | Where Google carried it for 3.4 (`kernel/common`, `deprecated/android-3.4`) |
|---|---|---|---|
| Default user/role/range selectors | 27 | `aa893269de6277b44be88e25dcd5331c934c29c4` (Eric Paris, 2012) | `7fea6d1` |
| `default_type` | 28 | `eed7795d0a2c9b2e934afc088e903fa2c17b7958` (Eric Paris, 2012) | `15879c0` |
| Constraint names | 29 | `a660bec1d84ad19a39e380af129e207b3b8f609e` (Richard Haines, 2013) | `61776bf` |
| **Extended permissions for ioctls** | **30** | `fa1aa143ac4a682c7f5fd52a3cf05f5a6fe44a0a` (Jeff Vander Stoep, 2015; first in mainline v4.3) | `631a078` |
| Fix for conditional rules | n/a | `f3bef67992e8698897b584616535803887c4a73e` | `d9349de` |
| Prerequisite cleanup | n/a | `83d4a806ae46397f606de7376b831524bd3a21e5` | `1a65138` |
| Android-M format compatibility | n/a | none (Android only) | `3f3f88f`: **not wanted**: its own text says it is "NOT intended for new Android devices" |

Tip of the branch used: `40bb591cb6abaf540bf9a988e3fac0ca86368865` (fetched 2026-11-05). Mainline's v3.4 to v4.3 SELinux history is not reachable from here (kernel.org history pages and the GitHub API are blocked), so these references come from Google's branch, whose commit messages carry the mainline IDs.

Results of trying it on a separate copy of our kernel:

| Attempt | Result |
|---|---|
| Apply the seven commits above one by one (`git apply`) | All seven **apply cleanly**, but the result **does not compile**: `slow_avc_audit` takes an extra `flags` argument that our 3.4.5-based tree lacks. An older prerequisite (not identified from the shallow history) is missing, so cherry-picking alone is not enough. |
| Take Google's android-3.4 `security/selinux` plus the LSM glue files wholesale (`include/linux/security.h`, `lsm_audit.h`, `security/security.c`, `capability.c`, `commoncap.c`, `lsm_audit.c`, `security/Kconfig`), keep our `nlmsgtab.c`, then reverse-apply the Android-M compatibility commit | **Compiles** with `pxa986_golden_rev02_defconfig` plus the SELinux options, using the pinned arm-eabi-4.6 compiler: `zImage` 3,985,744 bytes. `avc_has_extended_perms` and the xperm cache are in `vmlinux` (symbol check). 26 files changed, +1,366 / -139 lines (excluding a generated version header). The same without the reverse-apply (M-compat included) also compiled: 3,985,920 bytes, 27 files, +1,420 / -142. |
| Three further Google files were *not* taken because they pull in unrelated Android macros (`nlmsgtab.c`, `audit.h`, `binfmts.h`) | The only loss: `LSM_UNSAFE_NO_NEW_PRIVS` is defined but never set (our kernel has no `no_new_privs`). |
| Reverse-apply the M-compatibility commit (`3f3f88f`) | **Applies cleanly and the kernel still compiles** ([04-experimental-kernel-build-minimal.log](build-logs/phase7/04-experimental-kernel-build-minimal.log)). This is the version of the experiment that contains only what Android 7 needs. |

Reproduce: `tools/selinux/make-experimental-kernel.sh WORKDIR PRISTINE_CLONE ARM_EABI_PREFIX PERL_SHIM` (about three minutes; log: [03-experimental-kernel-build.log](build-logs/phase7/03-experimental-kernel-build.log)). It clones the pinned tree into `WORKDIR`, never writes to it, and builds only there.

Not done, and needed for a real kernel:
- **Binder hooks.** Google's `binder.c` has five `security_binder_*` calls (set context manager, transaction, two transfer-binder sites, transfer-file). Our `binder.c` has none, so binder IPC would not be mediated by policy. Not applied (Samsung's `binder.c` differs from Google's by about 50 lines and needs a careful, minimal port). Without them the system may boot but the `binder` rules in the policy have no effect: that is a security gap, not a boot blocker (assumption, UNKNOWN until run).
- **Run-time verification.** I cannot run this kernel (no phone, no emulator for this board). Plan for Phase 8: put the same `security/` files into a generic ARM 3.4.x kernel that QEMU can boot, load the compiled version-30 Android policy, and read `/sys/fs/selinux/policyvers`. That tests the loader and ioctl-permission logic; it does not test this phone. (Whether `qemu-system-arm` is available here was not checked.)

## 4. Is the back-port practical for 3.4.5? (item 5)

- **Size is bounded:** about 1.4k lines in 26 files, none outside `security/` and two headers, and public (GPL, Google's branch).
- **Fit is good:** the Samsung tree's `security/` files had no vendor changes; Google's files replaced them and the tree compiled with the pinned compiler.
- **Risks:** no run-time test; binder hooks; `no_new_privs` absent; Google's tree is 3.4.x with later security fixes, so sync is a larger jump than the minimum. The "minimal seven commits" route failed on a missing prerequisite, so the wholesale route is the realistic one.
- **My assessment:** feasible, moderate effort, medium risk until it runs under an emulator. It does **not** need any change to Android's policy, which is the property that matters most.

## 5. Policy compilation on the host (items 6 and 7)

Method (`tools/selinux/build-policy-conf.sh`): `checkpolicy` and `libsepol` built from AOSP `external/selinux` tag `android-7.1.2_r36` (`89ade431…`) with host gcc and a flex taken from an Ubuntu package unpacked in a scratch folder (nothing installed); `policy.conf` assembled with `m4` exactly as `system/sepolicy/Android.mk` does (144 input files, 29 from `vendor/cm/sepolicy`; `userdebug`; `target_needs_platform_text_relocations=true` as in our BoardConfig). The device has no sepolicy of its own yet. No rule was removed or edited. Log: [01-policy-compile-versions.log](build-logs/phase7/01-policy-compile-versions.log).

| `checkpolicy -M -c` | Result |
|---|---|
| **30** | Success, 0 errors |
| 29, 28, 27, 26 | Fail, **1 error each**: `libsepol.avtab_write_item: policy version N does not support ioctl extendedpermissions rules and one was specified` |

All of it comes from the kernel's version ceiling, because `-c 26` is what the unmodified kernel could accept; there are no other errors, so no other incompatibility with the older format.

The five `allowxperm` rules (all narrow `ioctl` to a list of commands):
- `app.te`: apps may use only unprivileged socket ioctls on their own TCP/UDP/raw sockets (except `bluetooth`).
- `domain.te`: every domain, only the unprivileged ioctls on Unix sockets.
- `mediaserver.te`, `mediadrmserver.te`: only unprivileged socket ioctls.
- `priv_app.te`: one ioctl (read the MAC address) on UDP sockets.

Five matching `neverallowxperm` assertions (`isolated_app`, `mediadrmserver`, `mediaserver`, `shell`, `untrusted_app`) are compile-time checks and are written to no file.

**Why removing them is not a neutral workaround:** these domains are given the plain `ioctl` permission on those socket classes (`create_socket_perms` includes `ioctl`). With no `allowxperm` rule, the `ioctl` permission has **no command filter**, so every ioctl would become allowed. Deleting the five rules compiles at version 26 only by granting more than the shipped policy does (and I did not test the result, per your rule). So there is **no semantics-preserving version-26 policy**: the kernel must be extended.

## 6. SELinux outcome (decision for you)

| Option | Status after Phase 7 |
|---|---|
| A. Back-port to version 30 in a kernel | **Recommended.** Compile-proven in a copy; needs binder hooks and an emulator test. |
| B. Strip rules, build at 26 | **Rejected**: widens access, not equivalent. |
| C. Run without SELinux (SM-T110 approach) | **Not recommended.** Disables a core security feature. Only with your explicit decision, for a bring-up build. Not done. |

## 7. Part B: libGAL security review (not applied)

### What the linker exception changes (SOURCE: bionic `linker.cpp`, `linker_phdr.cpp`, and `patches/bionic-libGAL-textrel.patch`)
- Without it: a library with text relocations is refused when the process's target SDK is above 22 (and, with our board flag, is not the platform's own value). Android's system processes pass; apps targeting SDK 23 and above (including SystemUI at 25) do not.
- With it (opt-in flag `GOLDENVESS3G_LIBGAL_TEXTREL`): the refusal is skipped only when the library's resolved path equals `/system/lib/libGAL.so`. Everything else keeps the rule. The linker then does what it already does for older apps: `mprotect` the text pages writable (never writable and executable at once: bionic clears the execute bit), applies the relocations, and `mprotect`s them back to read and execute.
- Measured on the dump's `libGAL.so`: 4,001 relocations in code touching **116 pages = 464 KiB** that become private (not shared) in every process that loads it (STATIC; 1.09 MB of text, 272 pages). Per GL process.
- It does **not** remove the relocations or make the library safer. It permits what Android 6 and later forbid for apps.

### SELinux permissions required
- The second `mprotect` (making a modified private file mapping executable again) is checked as **`execmod`** on the file's type (SOURCE: SELinux `file_mprotect`; text relocation is the textbook trigger; this is needed in *every* process that relocates `libGAL`, platform or app, independent of the linker exception).
- With `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS := true`, `system/sepolicy/domain.te` relaxes two `neverallow` rules (SOURCE): `execmod` becomes allowable on `system_file`, and for non-app domains. So a device rule `allow <domain> system_file:file execmod;` compiles. Without the flag, no such rule can compile at all, so **any text-relocation library (including the ones platform daemons load) depends on that flag. That flag was set in Phase 4 as a skeleton default and is a security-relevant decision; I have marked it as pending in `BoardConfig.mk`.**
- Which domains load libGAL (from the dump's dependency graph, STATIC): it is needed by `gralloc.mrvl`, `libEGL_MRVL`, `libGLESv*_MRVL`, `libHWComposerGC`, `libgcu`, `libcameraengine`. So: `surfaceflinger`, `bootanim`, `mediaserver` (video and camera), and every app process that uses hardware drawing (all `appdomain` members; the isolated sandbox cannot reach the GPU). Whether `system_server` loads it is UNKNOWN.

### Can `execmod` be scoped narrowly?
| Dimension | Possible? |
|---|---|
| Source domain | Yes: grant per domain (`surfaceflinger`, `bootanim`, `mediaserver`, `{ appdomain -isolated_app }`), never to `isolated_app`; `system_server` only if proven necessary (policy forbids it `execmem`, and `execmod` on `system_file` would provide almost the same power). |
| Target file type | **Not narrowly with the shipped rules.** `domain.te` only exempts `system_file`, so the grant covers *every library labelled `system_file`* (all of `/system`). A dedicated type (`libgal_file`) would violate the `neverallow` and fail to compile unless `domain.te` is changed to add that one exemption. That is a change to platform policy (adds one exception, review required), but it would shrink the blast radius from all of `/system` to one file. This is the best available scoping and is **not applied**. |

### Security consequences
1. **Apps:** the policy already gives every app `execmem` (`app.te`: `allow appdomain self:process execmem`, for the JIT), so `execmod` on a system library adds little *beyond what apps can already do*. The increase is real but small.
2. **Native services:** `surfaceflinger`, `mediaserver` and `bootanim` have **no** `execmem` rule today. `execmod` gives them a new way to run modified code from a file-backed mapping. Memory-corruption bugs in these processes become easier to turn into code execution. These are the high-value targets.
3. **`system_server`:** has `neverallow … execmem`; an `execmod` grant would sidestep that intent. Avoid.
4. Text pages become private dirty memory (464 KiB per process) and lose the hardening that read-only shared text provides. Brief read-write window on the text during loading.
5. With a broad `system_file` grant, any domain given it could do this to *any* system library, not only `libGAL`.

### Alternatives
| Alternative | Verdict |
|---|---|
| Get a `libGAL` without text relocations | Not possible without the vendor's object files. Rewriting the binary is not realistic. |
| Offline pre-relocation (prelink-style) | Android 7's linker has no support; would need loader changes: worse. |
| Software rendering (Android's own `libGLES_android`) | Android 7 only ships ES 1 software rendering here; the UI would need ES 2. Not a viable full replacement. |
| Open GPU stack for the GC1000 | Needs a 3.4 kernel DRM driver for it: a separate large project. |
| An older Android (6.0 forbids it for SDK 23 too; 5.1 allows it) | Outside the project's target. Noted only as the historical reason the vendor driver is built this way. |
| Per-app `targetSdkVersion` ≤ 22 | Not controllable for SystemUI and third-party apps. |

### Verdict on Part B
- The exact-path linker patch, as written, is **small and auditable**. The security cost is almost entirely the SELinux grant, not the patch.
- **Acceptable only if all of these hold:** enforcing SELinux (not option C); grants per domain from the table above with `isolated_app` and `system_server` excluded; preferably a dedicated `libgal_file` type with a one-line `neverallow` exemption instead of `execmod` on all of `system_file`; the owner signs off in writing; documented as an experimental-build risk. **Not acceptable** as a broad `appdomain system_file execmod` default or on a device used for sensitive data.
- The patch stays unapplied until the SELinux back-port runs and you decide.

## 8. What must be resolved before Phase 8, and GO / NO-GO

Must be resolved or decided first:
1. **You decide** SELinux option A (recommended) or C, and whether the text-relocation flag (`TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS`) stays on.
2. **You decide** the libGAL scoping (section 7) once graphics is otherwise ready.
3. Provide official Samsung files and partition data (see the second document, Part D). Nothing can be extracted or sized without them.
4. A build host with the disk and userland described in the second document (your ThinkPad, or another machine).
5. Approval to write the binder-hook port and to run a QEMU load test of the back-ported SELinux code (a kernel *source* change in a separate copy, not the production tree).

**Recommendation: GO** for Phase 8 as *computer-only preparation* (binder-hook port in a copy, emulator test of policy loading, isolated build environment, extraction tooling dry runs once firmware exists). **NO-GO** for any hardware test, flashing, or full ROM build until: official firmware and partition data are in hand, the SELinux back-port has loaded the version-30 policy under emulation, and the libGAL scoping decision is made. Nothing built so far is a candidate for a device.

## 9. Exact inputs and a second build

| Item | Value |
|---|---|
| `system/sepolicy` | cm-14.1 `83840c7f863cd30bd0df3c6db3701e39eee2a097` |
| `vendor/cm` | cm-14.1 `3747219d52e0203805c1a9c48bcc28ad1acfa5db` |
| `external/selinux` | AOSP tag `android-7.1.2_r36` = `89ade431ecff217e0ce7752fda81b5e4e404a293` |
| Kernel | `44afe4cf6023bf39c18bad72185003a40915fad2` |
| Google reference branch | `kernel/common` `deprecated/android-3.4` = `40bb591cb6abaf540bf9a988e3fac0ca86368865` |
| Compiler | pinned `arm-eabi-4.6` (GCC 4.6.x-google 20120106) |
| Host tools for the policy | gcc (host), bison (host), flex 2.6.4 (Ubuntu package unpacked in scratch), `-fcommon` |

Kernel experiment builds: [03](build-logs/phase7/03-experimental-kernel-build.log) (M-compatibility commit included) and [04](build-logs/phase7/04-experimental-kernel-build-minimal.log) (without it). The `zImage` hashes differ between runs because the build embeds a user name and timestamp; the images are not kept and must not be flashed anywhere.

## 10. Limitations
- Nothing was run on a kernel, an emulator or a phone. "Compiles" proves syntax and linkage only.
- The policy test used the base Lineage policy with no device policy (none exists). A real device adds rules.
- The upstream history for 3.4 to 4.3 could not be browsed; the mapping of commits comes from Google's branch messages.
- The `execmod` analysis is from reading SELinux and policy sources; no denial was observed.
