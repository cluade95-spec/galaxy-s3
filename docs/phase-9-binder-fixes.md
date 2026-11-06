# Phase 9, Part B: Binder fixes beyond the Phase 8 hooks

Phase 8 added only the LSM hook calls to `drivers/staging/android/binder.c`. This part asks which other Google binder fixes matter.
Proposed patches are in `tools/selinux/patches/proposed/`. **None was applied to the pinned kernel.** All testing used disposable copies, and no phone was touched.

Labels: PROVEN (observed), STATIC (read only), EMULATOR (QEMU, not hardware), UNRESOLVED.

## Method

1. Listed binder commits on Google's `kernel/common` `deprecated/android-3.4`, `3.10` and `3.18` that postdate the Samsung 3.4.5 binder.
2. Tried to apply each to a copy of the binder source. Older branches' fixes that did not apply were adapted by hand against the 3.4.5 code.
3. Compiled for ARM with the pinned `arm-eabi-4.6` toolchain and ran the Phase 8 binder tests (19/19).
4. For the one fix with a plausible emulator trigger (use-after-free on thread exit), wrote a probe and ran it with `slub_debug=FZPU`.

## Proposed patches

| ID | Fix | Source | Applies to 3.4.5 as-is? | Tested | Security impact | Needed for Android 7.1.2? |
|---|---|---|---|---|---|---|
| PB1 | `binder_proc_show` checks the `binder_proc` is still on `binder_procs` before printing (debugfs race, freed proc) | Google android-3.4 `b0bd81a6` / `7a9c5be5` | Yes | compiles; 19/19 pass; race not reproduced | Use-after-free read through binder debugfs. Reachable only by who can read `/sys/kernel/debug/binder`. Low if debugfs is not mounted or not readable. | Optional |
| PB2 | `binder_free_thread`: if the thread's wait queue is still registered with epoll, `wake_up_poll(POLLHUP\|POLLFREE)` then `synchronize_rcu()` before `kfree(thread)` | Hand adaptation of `f5cb779b` / `5eeb2ca0` (from android-3.18; those do not apply to this older code) | No (hand adapted) | **Bug reproduced without it, gone with it** (below); 19/19 pass | Kernel use-after-free of a 256-byte slab object, triggered by an ordinary unprivileged sequence of binder + epoll calls. Memory-corruption class, could be a local privilege escalation primitive. | **Required** (see decision) |
| PB3 / PB3b | Reject a transaction whose target process is the sender's own process | `7aa135fc` | PB3 for unhooked source; PB3b for the hooked source | compiles; 19/19 pass | Closes a path that allowed a process to make itself its own target (logic flaw, used in exploit chains). | Optional |
| PB4 | `files_lock` mutex protecting `proc->files`, with `__task_*` wrappers | `7f3dc008` (android-3.18 `e3ed622e7` does not apply) | No (hand adapted) | compiles; 19/19 pass; race not reproduced | Use of a stale `files_struct` pointer after `binder_vma_close()` queues the release. Memory-safety class. | Optional but recommended |

PB3 lesson (PROVEN): applying plain PB3 with `git apply -C1` put the hunk in the wrong branch of `binder_transaction` (compiler warned that `target_proc` could be used uninitialised). PB3b was rewritten against the hooked file and applies without fuzz. Do not use reduced context for security patches.

## PB2 reproduction (EMULATOR)

Probe (`gvmode=epoll`, `tools/selinux/phase9/init-audit.c`): start a context manager, open a non-blocking binder fd, send a synchronous transaction and consume `BR_TRANSACTION_COMPLETE`, register the fd with `epoll_ctl(ADD)`, call `BINDER_THREAD_EXIT`, close the epoll fd, then open 64 fresh binder fds. Boot with `slub_debug=FZPU`.

| Kernel | Description | Result |
|---|---|---|
| k0 | pinned-source binder, no Phase 8 patch | `BUG kmalloc-256: Poison overwritten` |
| k2 | Phase 8 patch + hooks | `BUG kmalloc-256: Poison overwritten` |
| k3 | k2 + PB2 | no BUG |
| k4 | k3 + 13 SELinux follow-ups | no BUG |

Logs: `docs/build-logs/phase9/31-binder-B2-k{0,2,3}-epoll-probe.log`, `50-k4-C4-epoll-probe.log`.

What this proves: the unmodified binder source has a use-after-free on this code path, and PB2 removes the poison corruption in this probe. It does not prove the bug is exploitable on the real device, and it does not prove PB2 removes every variant. The first two probe versions saw nothing because `binder_poll` returns early when the thread has pending work; the third consumed `BR_TRANSACTION_COMPLETE` first. A negative probe is weak evidence; this positive-then-negative pair is the useful result.

PB2 caveat (STATIC, read from the pinned source): `binder_free_thread` is called from `binder_ioctl` (`BINDER_THREAD_EXIT`) and `binder_deferred_release`, in both cases with the global `binder_main_lock` mutex held. A mutex holder may sleep, so `synchronize_rcu()` is legal there. The cost is that all binder activity waits for an RCU grace period (typically milliseconds) whenever a thread that used poll exits. It only runs when the wait queue is still registered. Performance on the real device is UNRESOLVED. `CONFIG_DEBUG_ATOMIC_SLEEP` was not enabled in the emulator runs.

## Do the Samsung binder and Google's fixes match?

STATIC: the Samsung 3.4.5 `binder.c` is the old single-lock design (global `binder_lock`, `hlist_for_each_entry` with a `pos` argument). Fixes written for 3.18 (which uses newer helpers) do not apply textually; PB2 and PB4 are re-implementations of the same idea against 3.4.5. Neither was reviewed by a binder maintainer. The Samsung binder differs from Google's android-3.4 tip only where the Phase 8 hook patch changed it (not verified line by line for the whole file, only for the hunks that touch these functions).

## Decisions for this part

- PB2: **required** before any production kernel (reproduced bug).
- PB4: **optional but recommended** (same class; not reproduced).
- PB1, PB3: **optional**.
- Fixes in the original request's wording that are not in this list were not found to apply; "unnecessary" for anything else could not be established without a full binder history review, which was not done. UNRESOLVED: a complete comparison of every post-3.4.5 binder commit.

The SELinux binder hooks themselves are unaffected by these patches: all 19 binder hook tests pass with PB1-PB4 applied (k3, k4).
