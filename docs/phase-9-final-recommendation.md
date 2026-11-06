# Phase 9: final recommendation

Computer-only. No phone contact, nothing flashed, no ROM built. The pinned kernel clone (`44afe4cf6023bf39c18bad72185003a40915fad2`) was only read, and every experiment used disposable copies. The Phase 8 patch was not applied to it. The broad text-relocation flag stays off, the libGAL exception was not applied, SELinux was never disabled, no `allowxperm` rule was removed, and no audit rule was suppressed or weakened. The production device tree and the Phase 8 results were not changed.

Detail documents: [patch review](phase-9-selinux-patch-review.md), [binder fixes](phase-9-binder-fixes.md), [audit investigation](phase-9-audit-investigation.md), [PXA988 compatibility](phase-9-pxa988-compatibility.md), [libGAL alternatives](phase-9-libgal-alternatives.md).

## Decisions

| Question | Decision | Why, in one line |
|---|---|---|
| SELinux back-port (Phase 8 patch) | **Continue testing.** Not rejected; **not approved for production integration.** | No Critical finding and it matches Google's android-3.4 code, but 13 later security fixes are missing, nothing ran on hardware, and lockdep and sleeping-in-atomic checks were not run. |
| Additional binder fixes | **Required: PB2** (thread-exit use-after-free). **Optional but recommended: PB4.** **Optional: PB1, PB3.** | PB2's bug was reproduced on the unmodified pinned binder and removed by the fix. The others are unreproduced memory-safety or logic fixes. |
| libGAL exception | **Unresolved**, leaning unavoidable for GPU acceleration | The library cannot be rebuilt (no sources) or realistically rewritten (4,001 sites). Mesa software rendering would avoid it but is untested and slow. The owner chooses. |
| Full ROM build | **NO-GO** | No authenticated firmware or partition data, no hardware validation, open owner decisions, and the points above. |

## Proven, static, emulator, unresolved

**Proven (observed, logs in `docs/build-logs/phase9/`)**
- With no audit daemon, audit records go through printk and are cut by the kernel's rate limit. With the limit off, or with a NETLINK_AUDIT listener, all 14 expected enforced denials and both execmod denials appear (10/14 and 0/2 under the default). Enforcement results never changed.
- The real board config (`pxa986_golden_rev02_defconfig`) plus SELinux options and the patch compiles for ARMv7 with the pinned toolchain, with and without Samsung's ship options: zImage and 20 modules, 0 warnings in `security/` and `binder.c` in the default build.
- The defconfig has no SELinux, no audit and no `EXT4_FS_SECURITY` as shipped; they must be enabled.
- The proposals PB1 to PB4 and 13 SELinux follow-ups apply without fuzz to disposable copies and compile. One follow-up needed a hand adaptation (`kmemdup_nul` does not exist in 3.4).

**Static analysis (read, not executed)**
- The patch equals Google's android-3.4 SELinux changes except the reverted Android-M commit and the hook-only `binder.c`.
- 13 of 20 candidate later fixes apply; 7 do not (list in `docs/data/selinux-followup-fixes-apply-check.tsv`).
- `libGAL.so` has 4,001 text relocation sites; there are no user-space sources for it in any repository we have.
- `security/Kconfig` in the patch adds an unneeded, default-off `SECURITY_PERF_EVENTS_RESTRICT`.

**Emulator results (QEMU vexpress-a9; not hardware proof)**
- Policy version 30 loads; the 19-test enforcement matrix and 3 execmod tests pass on the patched kernel, with PB1 to PB4, and with the 13 follow-ups.
- Binder epoll use-after-free reproduced on the pinned-source binder and on the Phase 8 kernel, gone with PB2 (kernels k0, k2, k3, k4).

**Unresolved**
- Boot and behaviour on the real device; Samsung driver interactions; Android userspace.
- Lock correctness (lockdep), `CONFIG_DEBUG_ATOMIC_SLEEP`, boot-time and memory cost of the AVC/xperm caches.
- Whether PB2 adds noticeable binder latency (`synchronize_rcu()` under the global binder lock); whether PB4's and the unreproduced races are exploitable.
- The 7 follow-ups that do not apply, and the `NO_NEW_PRIVS` behaviour change in `commoncap.c` on the device.
- Which domains really load `libGAL.so`; Mesa software-rendering performance.
- A complete comparison of every post-3.4.5 binder commit.

## Remaining blockers

1. Authenticated firmware and partition data (none exist; the community dump is not authenticated).
2. A hardware test plan that the owner approves (no phone work was done or authorised here).
3. Owner decisions: libGAL path (E3 vs E4), and whether the first build omits GPS/codecs/modem libraries that also have text relocations.
4. Production kernel integration of the patch series: Phase 8 patch + the 13 follow-ups (+ `FU-adapt-kmemdup_nul`) + PB2, with PB4 recommended, built on the real config and checked with lockdep and sleep-in-atomic debugging in the emulator.

## Recommended next milestone (Phase 10, still computer-only)

1. Build the PXA988 config with the full series (patch, 13 follow-ups, adaptation, PB2, PB4) using `tools/selinux/phase9/make-pxa988-test-kernel.sh`; fix anything that breaks.
2. Re-run all emulator tests on a vexpress build with `CONFIG_PROVE_LOCKING`, `CONFIG_DEBUG_ATOMIC_SLEEP` and `slub_debug`.
3. Triage the 7 non-applying follow-ups by hand (adapt where relevant).
4. Prepare, but do not run, a hardware test plan for the owner's approval.

## Reproduction

All commands run from a checkout of this branch; scratch builds need the pinned kernel clone and `arm-eabi-4.6` as in Phase 8.

- Audit: `tools/selinux/phase9/init-audit.c` with kernel arguments `gvratelimit=off`, `gvklog=1`, `gvaudit=netlink`.
- Binder probe: kernel arguments `gvmode=epoll slub_debug=FZPU gvklog=1`.
- PXA988 compile: `tools/selinux/phase9/make-pxa988-test-kernel.sh WORKDIR PRISTINE CROSS SHIM PLAIN|SHIP [PATCH...]`.
- Proposed patches: `tools/selinux/patches/proposed/` (none applied to the pinned kernel).
