# Phase 9, Part A and D: SELinux back-port review

Scope: `tools/selinux/patches/android-3.4-selinux-backport.patch` (27 files, +1,387 / -139), the Phase 8 patch under review.
Nothing here was applied to the pinned kernel. All builds used disposable copies. No phone was touched.

## Evidence labels

- **PROVEN** = observed in a build or an emulator run, log in `docs/build-logs/phase9/`.
- **STATIC** = read from source or diffs, not executed.
- **EMULATOR** = ran on QEMU vexpress-a9, not on the device. Emulator success is not hardware proof.
- **UNRESOLVED** = not determined.

## How it was compared with Google's android-3.4

The patch is a back-port of the series on `kernel/common` `deprecated/android-3.4` (mainline IDs include `aa893269` v27, `eed7795d` v28, `a660bec1` v29, `fa1aa143` xperms, `f3bef679`, `83d4a806`).

- STATIC: the patch is byte-identical to Google's android-3.4 tip for every SELinux file except two.
  - `security/selinux/ss/avtab.c`: Google's Android-M compatibility commit `3f3f88f` was reverse-applied in Phase 8. It is not wanted (it changes how pre-M policies are read).
  - `drivers/staging/android/binder.c`: only the four LSM hook calls are added. Google's tip also contains unrelated binder changes (Part B).
- This was a content comparison. It shows the patch matches Google's code. It does not show Google's code is bug-free (see High finding H1).

## Severity summary

| Severity | Count | Items |
|---|---|---|
| Critical | 0 | none found |
| High | 2 | H1 missing later SELinux fixes; H2 stock binder use-after-free (pre-existing, not caused by the patch) |
| Medium | 3 | M1 audit loss under printk rate limiting; M2 no hardware run; M3 `binder.c` hooks interact with unfixed binder races |
| Low | 4 | L1 one whitespace warning; L2 `printk` on an invalid class; L3 Samsung `SEC_RESTRICT_*` is independent; L4 unneeded `PERF_EVENTS_RESTRICT` option in `security/Kconfig` |
| Informational | several | see per-file table |

No Critical finding means: no defect was found that, in the tests run, silently disables enforcement, crashes the kernel, or loads a wrong policy. It does not mean none exists.

## Findings

**H1 (High, STATIC + EMULATOR). 13 later security fixes are not in Phase 8.**
Google's android-3.4 branch is older than 13 SELinux fixes that Google later put on its other branches (a318 / a310). 13 of 20 candidates applied to the patched tree, including: off-by-one in `setprocattr`, `selinux_socket_bind` address-length check, invalid-policy GPF, `xattr_getsecurity` out-of-bounds, double free, `policydb_init` memory leak, `sock_has_perm` fault, NUL-terminated context. They are in `tools/selinux/patches/proposed/selinux-followups/` (14 files with one adaptation) and the apply results are in `docs/data/selinux-followup-fixes-apply-check.tsv`.
- One (`28eb4b7b1`) uses `kmemdup_nul`, which does not exist in 3.4. It applied cleanly but failed to compile. `FU-adapt-kmemdup_nul.patch` replaces it with kmalloc + memcpy + NUL. Lesson: "applies cleanly" is not "correct".
- With all 13 applied (kernel k4, zImage hash prefix `26281b98`): the 19-test matrix passed 19/19, execmod 3/3, no regression, no new warnings (EMULATOR).
- 7 did not apply (`804d58534`, `73ec15e6a`, `c2103c267`, `b25a2f956`, `f0f61c29d`, `df46bc83c`) or need a missing hook (`43ab3a2a8`). They were not forced. Their security value on this kernel is UNRESOLVED.
- Recommendation: do not integrate the Phase 8 patch without the 13 follow-ups.

**H2 (High, EMULATOR, pre-existing). Stock binder use-after-free.** See `phase-9-binder-fixes.md`. The unmodified pinned `binder.c` frees a thread's wait queue while epoll may still reference it. Reproduced on the unpatched kernel (k0) and with the Phase 8 patch (k2); not reproduced with PB2 (k3, k4). The Phase 8 patch neither causes nor fixes it.

**M1 (Medium, PROVEN). Audit records lost to printk rate limiting.** See `phase-9-audit-investigation.md`. Policy enforcement is correct; only the record delivery is lossy without an audit daemon.

**M2 (Medium). No hardware runtime evidence.** Everything above ran on QEMU or as static compile.

**M3 (Medium, STATIC). Hook placement.** The hooks are correct and tested for allow/deny, but they sit in a binder driver that still has the races in Part B. The hooks are not themselves racy.

**L1 (Low, PROVEN).** `git apply` reports one whitespace error (`services.c`, space before tab in a `printk`). Cosmetic.

**L2 (Low, STATIC).** The patch's diff context contains a `printk(KERN_WARNING "SELinux:  Invalid class")` line (the whitespace warning in L1 points at it). No behavioural effect.

**L4 (Low, STATIC).** The patch carries `SECURITY_PERF_EVENTS_RESTRICT` in `security/Kconfig`. It is off unless enabled and Android 7.1.2 does not need it. The test kernel scripts never enable it, so it was off in all builds. Consider dropping it from a production patch.

**L3 (Low, STATIC).** Samsung's `SEC_RESTRICT_*` options restrict root actions through ordinary DAC checks and are independent of SELinux. They were present in the SHIP build and caused no conflict.

## File-by-file review

Columns: lines (+/-), result of review, class.

| File | +/- | What it does (from the diff) and review result | Class |
|---|---|---|---|
| `drivers/staging/android/binder.c` | 21/0 | Adds only the four `security_binder_*` calls (set_context_mgr, transaction, transfer_binder, transfer_file) with error returns. Matches Google. Binder races not caused by hooks remain (H2, Part B). | Info (M3) |
| `include/linux/lsm_audit.h` | 7/0 | New `lsm_ioctlop_audit` (path + `u16 cmd`) and `LSM_AUDIT_DATA_IOCTL_OP`. Struct additions only. | Info |
| `include/linux/security.h` | 36/6 | Declares the binder hooks and no-op stubs for builds without a LSM. | Info |
| `security/Kconfig` | 9/0 | Adds `SECURITY_PERF_EVENTS_RESTRICT` (bool, off unless enabled; when on, perf_event_paranoid defaults to 3). Not part of SELinux proper and not needed by Android 7.1.2. Leave it off. | Low (L4) |
| `security/capability.c` | 26/2 | Default (no-LSM) versions of the new hooks. | Info |
| `security/commoncap.c` | 5/2 | `cap_bprm_set_creds`: setuid-exec of a file gains privilege only if `capable(CAP_SETUID)` is true and `NO_NEW_PRIVS` is not set. This is a tightening that only applies when a process sets `NO_NEW_PRIVS`. Needs the 3.4 `prctl` support that the pinned tree already has (it compiled). | Info |
| `security/lsm_audit.c` | 15/0 | Prints `ioctlcmd=` for xperm audit. Observed in A2 (`ioctlcmd=3`). | Info |
| `security/security.c` | 22/2 | Dispatch for the four binder hooks, plus an `sb_mount` hook wrapper. | Info |
| `security/selinux/avc.c` | 409/21 | Adds the extended-permission decision cache (`avc_xperms_*` allocate/free/copy/populate), `avc_has_extended_perms`, `avc_update_node` driver/xperm arguments, and audit of ioctl commands. Allocation failure paths free partial nodes. Follow-up `942ec5b0c` (counter leak on error) is missing without H1. Uses existing AVC locking; no lockdep run. | High (H1) |
| `security/selinux/hooks.c` | 194/40 | Adds `selinux_binder_*` (4 hooks), `ioctl_has_perm` (xperm check in `selinux_file_ioctl`), `selinux_mount`, RCU freeing of inode security (`inode_free_rcu`), `genfs_get_sid` refactor, and `bprm_set_creds` changes. The follow-ups `e4a8a7b8d`, `989dcfa49`, `669d07053` touch this file; five more do not apply (H1). | High (H1) |
| `security/selinux/include/avc.h` | 5/0 | Prototypes. | Info |
| `security/selinux/include/classmap.h` | 4/1 | Adds the `binder` class (`impersonate`, `call`, `set_context_mgr`, `transfer`) and `capability2` perms `wake_alarm`, `block_suspend`. Needed so the Android 7.1.2 policy loads. | Info |
| `security/selinux/include/objsec.h` | 4/1 | `inode_security_struct` gets a union of `list` and `rcu_head` (for RCU free). | Info |
| `security/selinux/include/security.h` | 34/2 | Raises the supported policy version to 30 and declares xperm services. The built kernel exports `security_compute_xperms_decision` (PROVEN in the PXA988 build). | Info |
| `security/selinux/netnode.c` | 2/1 | `rcu_dereference_protected` with a lockdep annotation. No behaviour change. | Info |
| `security/selinux/ss/avtab.c` | 90/14 | Reads/writes xperm avtab entries and handles the new rule specifiers. Android-M compatibility commit reverted. Verified by loading the real v30 policy. | Info |
| `security/selinux/ss/avtab.h` | 33/1 | New xperm flags and structures. | Info |
| `security/selinux/ss/conditional.c` | 26/4 | `cond_compute_xperms` and xperm-aware `cond_compute_av`. | Info |
| `security/selinux/ss/conditional.h` | 4/2 | Prototypes for the above. | Info |
| `security/selinux/ss/constraint.h` | 1/0 | `type_names` set in constraint expressions (v29). | Info |
| `security/selinux/ss/context.h` | 20/0 | `mls_context_cpy_high`. | Info |
| `security/selinux/ss/mls.c` | 24/0 | `default_range` (v27) handling in `mls_compute_sid`. | Info |
| `security/selinux/ss/policydb.c` | 136/9 | Reads/writes v27-v30 policy (constraint names, `type_set`, default_type). Follow-ups `f643372c9`, `9ae2dad35`, `b6c410582` fix an invalid-policy fault, a leak and a double free here (H1). | High (H1) |
| `security/selinux/ss/policydb.h` | 25/0 | New version constants and fields. | Info |
| `security/selinux/ss/services.c` | 228/30 | xperm decision computation, object-default handling, bounds updates. The `28eb4b7b1` NUL-termination fix applies here (H1). | High (H1) |
| `security/selinux/ss/services.h` | 6/0 | Prototypes. | Info |
| `security/selinux/xfrm.c` | 1/1 | `GFP_KERNEL` to `GFP_ATOMIC` in an allocation that may run in atomic context. | Info |

## Review areas the request listed

| Area | Result | Label |
|---|---|---|
| Correctness | Matches Google tip; policy v30 loads; 19/19 enforcement tests and 3/3 execmod tests pass | EMULATOR |
| Missing dependencies | Does not need other patches to compile; needs `kmemdup_nul` replacement only for follow-ups | PROVEN (build) |
| Initialization order | Policy loads after `selinux_init`; no new init-time dependency. Emulator boot order matched Phase 8. | STATIC + EMULATOR |
| Locking | Xperm cache follows existing avc locking. No new lock inversion found by reading. Not lock-checked (`CONFIG_PROVE_LOCKING` not run). | STATIC, UNRESOLVED on lockdep |
| Memory handling | `slub_debug=FZPU` was used only for the binder epoll probes (no poison report on the patched kernels k3/k4). The 19-test and execmod runs had no memory debugging, so SELinux memory handling is not dynamically checked. Leak fixes missing without H1. | EMULATOR |
| Error paths | Read; known upstream bugs are exactly the H1 list | STATIC |
| Samsung / PXA988 assumptions | See `phase-9-pxa988-compatibility.md` | PROVEN (build) |
| Regressions | Existing Phase 8 tests still pass with the follow-ups (k4) | EMULATOR |
| Silent weakening of existing controls | Not found. Default policy mode, `CONFIG_SECURITY_SELINUX_DEVELOP`, and enforce switch unchanged. The `execmod` exception stays confined to `libgal_file`. | STATIC + EMULATOR |

## Verdict

Decision for this document: **continue testing; not approved for production integration** until H1 is applied and compiled on the real config (done in the disposable copy, see compatibility doc), a hardware run exists, and lockdep has been run. See `phase-9-final-recommendation.md`.
