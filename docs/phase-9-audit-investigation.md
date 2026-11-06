# Phase 9, Part C: why extended-permission and execmod denials left no audit records

Phase 8 saw that xperm and execmod denials were enforced (the syscall failed with the right error) but no `avc: denied` line appeared on the console. This part finds out why.
No audit rule was suppressed, removed or weakened. The only change was how records are delivered and collected. QEMU only; no phone.

## Answer

**PROVEN (EMULATOR): the records were generated. They were dropped on the way to the console by the kernel's printk rate limit.** With no audit daemon registered, the kernel prints each audit record through `printk`, and `audit_printk_skb` uses `printk_ratelimit` (default 10 messages per 5 seconds). The test harness produces bursts larger than that, so later records, including the xperm and execmod ones, were discarded.

Two ways of showing it, neither of which changes any policy or audit rule:

1. Set `printk_ratelimit` to 0 (no limiting) before loading the policy.
2. Register as the audit daemon through `NETLINK_AUDIT` (what Android's `logd` does) and read the records from the socket.

## Experiments (same policy, same kernel k3/k4, same test set)

Harness: `tools/selinux/phase9/init-audit.c`. Switches: `gvratelimit=off`, `gvklog=1` (counts records in the kernel ring buffer), `gvaudit=netlink`.

Expected enforced denials from the 19-test matrix: 14. Expected execmod denials: 2.

| Run | Delivery | Enforced `avc: denied` found | `ioctlcmd=` records | execmod records |
|---|---|---|---|---|
| A1 tests, default | printk, rate-limited | 10 of 14 | 0 | n/a |
| A2 tests, `printk_ratelimit=0` | printk, unlimited | 14 of 14 | 3 | n/a |
| A5 tests, NETLINK_AUDIT | queued to daemon | 14 of 14 (34 avc records received) | 4 lines in the log | n/a |
| A3 execmod, default | printk, rate-limited | 0 of 2 | n/a | 0 |
| A4 execmod, `printk_ratelimit=0` | printk, unlimited | 2 of 2 | n/a | 2 |
| A6 execmod, NETLINK_AUDIT | queued | 2 of 2 (21 avc records) | n/a | 2 |
| C5 (with 13 follow-ups, k4), NETLINK_AUDIT | queued | 14 of 14 | 4 lines in the log | n/a |

In every run the test results were identical (19/19 and 3/3 pass), so enforcement was never affected. `audit_lost` was 0 throughout, so the kernel audit backlog itself did not overflow in these runs.

Logs: `docs/build-logs/phase9/10-audit-A1..A6-*.log`, `50-k4-C5-tests-netlink-audit.log`.

The "ring" counts in A1 to A4 come from reading the kernel log with `syslog(3)`. In the NETLINK runs the ring shows 0 avc lines because records go to the socket instead of printk; the `NETLINK-AUDIT summary` lines are the counts.

## The questions that were asked

| Question | Result |
|---|---|
| Records generated but not collected? | Yes. Generated; lost in printk rate limiting. PROVEN (A1 vs A2). |
| QEMU capture problem? | No evidence of one. With the rate limit off, the same serial console carried all records, and the NETLINK runs did not use the console at all and also saw all records. This is an inference from A1 to A6, not a separate test of QEMU's console. |
| Incomplete audit configuration? | No. `CONFIG_AUDIT` and `CONFIG_AUDITSYSCALL` were on; `audit: initialized` appears at boot. Note the boot line `audit: initializing netlink socket (disabled)`, which is normal until a daemon registers. |
| Samsung kernel differences? | Not tested on a Samsung-specific path. The Samsung PXA988 config builds with the same options (see compatibility doc), but the rate-limit behaviour itself comes from generic printk and audit code. On the device, Android's `logd` registers with `NETLINK_AUDIT`, which corresponds to the A5/A6 behaviour. UNRESOLVED on hardware. |
| Does ioctl-xperm auditing work? | Yes: `ioctlcmd=` appears once the rate limit is off or a daemon is registered (3 records in A2). |

## Consequences for the project

- Phase 8's statement "denials enforce but no audit line appeared" stays true as an observation; the cause is now known and is a log-delivery issue, not a policy or kernel enforcement problem. Phase 8 results were not overwritten.
- When testing on a real device, record denials through the audit netlink socket (logd, or `auditd`), not by watching the console; `dmesg` may miss records during bursts.
- Do not "fix" missing records by adding `dontaudit` or by disabling rules. The `.dontaudit` policy variant from Phase 8 is not used here.
- Raising `printk_ratelimit` is a debugging aid only, because it can let a user-triggered flood of denials through to the console. Do not ship it.

## Not covered (UNRESOLVED)

- Behaviour with Android's real `logd` and its `kauditd` backlog limit on the device. Backlog overflow (`audit_lost`) under heavy load was not stressed.
- Samsung kernel config interactions (for example Samsung's own logging hooks), since no device run exists.
