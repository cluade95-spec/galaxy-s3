# Phase 4: cellular investigation (Marvell RIL on Android 7.1.2)

Question: can the stock Marvell RIL (`libmarvell-ril.so`) realistically be adapted to Android 7.1.2 when there is no known newer-Android Marvell phone to copy from?

**Short answer:** plausible but unproven, and the single largest risk in the project. Nothing here was run. Everything below is static analysis of a community dump (rooted, unverified origin) and of LineageOS 14.1 sources. Labels: **STATIC** = read from binaries, **SOURCE** = read from LineageOS 14.1 source, **UNKNOWN** = not determinable from a computer.

## 1. What a version number does and does not prove

- **STATIC:** the RIL's `RIL_RadioFunctions` struct reports version 7 (struct at file offset 0xa2b90; `onSupports` returns 1).
- **SOURCE:** Android 7's `libril` accepts versions 6 to 12.
- That only means the RIL will not be rejected at load time. It says nothing about whether the requests Android 7 sends are handled, whether the library's dependencies exist, or whether the modem side works. The rest of this document is about those other things.

## 2. Request coverage (the main finding)

- **STATIC, moderate confidence:** the `onRequest` dispatcher indexes a 12-byte-entry table (base 0xa3698) by request id. Valid entries cover ids 0 to 123: 88 have handlers and 35 are marked unsupported (flag 8 or null handler). The unsupported ones are mostly CDMA, plus TTY mode (80/81), cell-info list (109/110), initial-attach APN (111), IMS (112/113), SIM APDU/channel (114-116), NV (118-121), UICC subscription (122), allow-data (123), ISIM auth (105), exit emergency callback (99).
- Only a 500-boundary split check was seen at dispatcher entry, so ids above 123 would read past the table. That is a potential crash or undefined behaviour, not a graceful "not supported".
- **SOURCE:** Android 7's telephony Java sends ids above 123 on a single-SIM GSM phone, in normal operation:

| Id | Request | Caller (LineageOS 14.1) |
|---|---|---|
| 124 | GET_HARDWARE_CONFIG | TelephonyDevController.registerRIL |
| 128 | SET_DATA_PROFILE | DcTracker.java:3445 |
| 129 | SHUTDOWN | ServiceStateTracker (power-off) |
| 130 | GET_RADIO_CAPABILITY | GsmCdmaPhone.java:2044 |
| 132 | START_LCE | Phone.java:518 (Phone constructor) |

- `RIL.java` has a fallback ("Faking RIL_REQUEST_GET_RADIO_CAPABILITY response") on error, but only if an error actually comes back. `libril` itself guards only ids 136/137.
- **Consequence:** a small interposer (shim between libril and the vendor RIL) that answers ids above 123 with `RIL_E_REQUEST_NOT_SUPPORTED` is very likely needed. It is not written. Writing it needs the exact table bounds confirmed from the official firmware's library, not from the dump.

## 3. Dependencies

| Need | State |
|---|---|
| `libstlport` | Removed from Android 7. Must be a vendor blob from official firmware (also needed by camera HAL). Listed as not in the community list. |
| sqlite3 deprecated functions (6 imported) | SOURCE: no `SQLITE_OMIT_DEPRECATED` found in the flags checked, so probably still exported. Must be confirmed by building. |
| `libsecnativefeature`, `libMILV`, `libwtpsp`, `libomission_avoidance` | Vendor blobs; present in dump, behaviour on N unknown. Several are flagged missing from the community proprietary list. |
| `requestToString` / `radioStateToString` from libril | SOURCE: N declares them `extern "C"`, so the imports should resolve. |
| Text relocations | The library is covered by the board text-relocation flag; this is a loader workaround, not a fix. |

## 4. Stack outside the RIL

- **STATIC:** the RIL talks AT commands (182 "AT" strings) over `/dev/citty*`, `/dev/cctdatadev1`, `/dev/cidatatty1`.
- Stock daemons: `nvm`, `diag`, `atcmdsrv`, `eeh`, `cploader`, `vcm`, `simal`, and script `tel_launch.sh`.
- `tel_launch.sh` inserts modules: cploaddev, seh, citty, msocketk, cci_datastub, ccinetdev, gs_modem, diag, gs_diag, cidatattydev. **`gs_modem.ko` was not among the 20 modules the Phase 2 build produced.** Why is unknown (may be built-in, a different config, or a prebuilt binary).
- The modem firmware lives in the MODEM partition (community claim: partition 11); NVM data is at partition 12 (CLAIMED). Neither partition table nor sizes are verified.
- `init.pxa988.tel.rc` in the skeleton is an empty stub with comments. Telephony is **BLOCKED**.

## 5. Precedent

- No Marvell-modem phone running Android 5 or newer was found. The `baffinlite` (GT-I9060) tree used earlier as a reference is **Broadcom** (`libbrcm_ril`), so it is not a precedent (corrected in earlier docs).
- LineageOS 14.1 has no Marvell RIL class in `frameworks/opt/telephony`; the vendor RIL must stand on the standard RIL interface alone.
- UNKNOWN: whether the GT-I8200 is single-SIM only (stock libril has dual-SIM extras).

## 6. What can and cannot be validated on a computer

Computer-only work that is possible: write the interposer; build with the shims; check symbol resolution of every blob against Android 7 libraries; emulate the dispatcher with fake requests in a host harness.

Not possible without hardware: whether the modem boots, whether the AT sequences work with Android 7's call/data stack, SIM, network registration, mobile data (netd/UID routing differences), emergency calls.

## 7. Assessment

- Passing version gate: yes (static).
- Likely work needed: interposer for ids above 123, libstlport blob, module/daemon bring-up with `gs_modem` question resolved, kernel netfilter options for Android 7 data.
- No evidence that calls or mobile data will work. Realistic outcomes: (a) works after moderate work; (b) registers but data/calls flaky; (c) never works, phone ships with Wi-Fi/Bluetooth/GPS only. Probability of each is not estimable from here.

## 8. Go/no-go for a future hardware test

Proceed to a hardware test only with the user's explicit approval and only when all hold:
1. Official firmware obtained and hash-checked from Samsung (not a mirror); phone identity confirmed as GT-I8200 (not I8200Q/N/L).
2. Real partition table obtained (not community sizes) and a verified stock backup plan exists.
3. Interposer built and host-tested; every telephony blob resolves against Android 7.
4. `gs_modem` question answered.
5. Test is first a non-flashing method if one exists (otherwise a documented, reversible procedure approved by the user).

Not met today: 1 to 4.
