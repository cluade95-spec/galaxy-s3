# Phase 5, Part B: cellular feasibility (Marvell RIL on Android 7.1.2)

Computer-only. Nothing was run on a phone or on the RIL itself; no firmware or modem image was obtained. This extends [phase-4-cellular-investigation.md](phase-4-cellular-investigation.md).

Evidence labels: **STATIC** = read from the community-dump binaries (`libmarvell-ril.so` etc.; rooted dump, origin unverified, so any finding must be re-checked against official firmware), **SOURCE** = read in LineageOS `cm-14.1` sources (shallow clones of `hardware/ril` and `frameworks/opt/telephony`, plus the kernel tree at the Phase 2 commit), **TESTED-HOST** = executed on this computer with fake code, **UNKNOWN** = cannot be settled without hardware.

## 1. Bottom line

- The vendor RIL implements the **basic GSM request set**: 88 request ids have handlers, including SIM status/PIN, dial/answer/hang-up, call list, SMS send/acknowledge, voice and data registration, operator, signal strength, radio power, data call setup/teardown and USSD. The full list is in [data/ril-request-coverage.tsv](data/ril-request-coverage.tsv) (STATIC).
- Android 7.1.2's `libril` forwards request ids up to 137. The vendor RIL's table ends at id 123. **Ids 124 to 137 are not table data in the vendor library, so they must never be forwarded to it.** A small interposer is needed. A prototype exists and passes a host logic test with a fake vendor library (TESTED-HOST), which proves only the filtering logic.
- Whether calls, SMS, mobile data, SIM detection and registration actually work depends on things that cannot be checked here: the modem firmware, the telephony kernel modules at run time, the daemons, and the AT-command behaviour. **Nothing about cellular is shown to work.** Realistic outcomes remain: works after moderate effort, partly works, or never works.

## 2. What Android 7 does with the vendor RIL

SOURCE:
- `libril` (`ril.cpp`) accepts a vendor RIL whose reported version is 6 to 12 (`RIL_VERSION_MIN` 6, `RIL_VERSION` 12). The Marvell RIL reports **7** (STATIC).
- That is more than a number check: `libril` keeps an explicit "imprecise version" path (`LAST_IMPRECISE_RIL_VERSION` = 12). For vendors at or below that version, many responses are interpreted by structure size (data call lists, SIM refresh v7, cell info). So a version 7 RIL is a supported case in Android 7's code, not an accident. It still does not prove the Marvell RIL's actual response structures fit those size checks (UNKNOWN).
- `libril` checks request ids against its own table (`s_commands`, ids 1 to 137) and sends valid ones to the vendor `onRequest`. It checks only 136 and 137 against the RIL version (needs 14 or higher; answers REQUEST_NOT_SUPPORTED itself).
- Without `ANDROID_MULTI_SIM`, `onRequest` takes four arguments. The vendor `onRequest` uses four argument registers and does not read a fifth (STATIC), which matches. The multi-SIM build flag must stay off.
- SETUP_DATA_CALL in Android 7 sends **7** strings (radio technology, profile, APN, user, password, auth type, protocol). That is the argument count used by RIL versions 6 and 7. Whether the Marvell handler accepts exactly these strings is UNKNOWN.

## 3. The request table

STATIC, moderate confidence (reconstructed by disassembling `onRequest`):
- `onRequest` is Thumb code. It looks up a 12-byte entry `{id, category, handler}` at table base + 12 x request id for ids below 500 (a second formula for 500 and above, unused here).
- Entries 0 to 123 are well formed: the first word equals the index. Category 8 or a missing handler means "unsupported", and the function then answers the request with error 6 (`RIL_E_REQUEST_NOT_SUPPORTED`) (STATIC).
- There is **no check against 123** for ids below 500. The entry for id 124 is `{0, 0, <function pointer>}`; as read, category 0 would run the category-0 pre-check function and then a real function that belongs to something else (my reading of the dispatch flow, not executed). Entries 125 to 130 hold function pointers and numbers where a small category is expected. The category is used as an index into a second table, so a large value reads far outside the library (for id 125 the value is 479,581, which is about 5.7 MB past the table). Whether that crashes depends on what memory happens to be mapped there. **Do not forward these ids: the result is undefined (misrouted request or crash).** Nothing was executed to see which.
- Unsupported ids (35): CDMA, TTY mode, cell info list (109, 110), initial attach APN (111), IMS (112, 113), SIM APDU basic/channels (114 to 116, except 117 which has a handler), NV items (118 to 121), UICC subscription (122), allow data (123), ISIM authentication (105), emergency callback exit (99).

## 4. Requests 124 to 137, one by one

"Sent by Android 7" is from SOURCE greps of `frameworks/opt/telephony` cm-14.1.

| Id | Request | What it means (ril.h) | Sent by Android 7? | Effect of an error reply | Reply the interposer gives | Why not "success" |
|---|---|---|---|---|---|---|
| 124 | GET_HARDWARE_CONFIG | No data. Returns the list of modems and SIMs (RIL_HardwareConfig). | Yes, `TelephonyDevController.registerRIL`, at telephony start, without a result handler. | None visible; a later handler only logs an error. | REQUEST_NOT_SUPPORTED | An empty success would tell the framework "no hardware exists". It could also hide the missing implementation. |
| 125 | SIM_AUTHENTICATION | Base64 challenge in, SIM response out (EAP-SIM/AKA style). | No startup caller seen in the greps. Intended for SIM-based authentication such as EAP-SIM (caller not traced). | That kind of authentication fails. Acceptable. | REQUEST_NOT_SUPPORTED | Success without a real SIM answer would let an authentication appear to succeed with bogus data. Never do this. |
| 126 | GET_DC_RT_INFO | Deprecated data connection real-time info. | No caller found. | n/a | REQUEST_NOT_SUPPORTED | A fabricated record would be wrong data. |
| 127 | SET_DC_RT_INFO_RATE | Deprecated. ril.h says "must not fail". | No caller found. | n/a | REQUEST_NOT_SUPPORTED | Flagged: this is the only one where ril.h asks for success, but nothing calls it. Revisit if a caller shows up. |
| 128 | SET_DATA_PROFILE | Send the APN list to the modem. Reply: none. | Yes, `DcTracker.setDataProfilesAsNeeded`, fire-and-forget with a null result. | None. Data uses the APN in SETUP_DATA_CALL. | REQUEST_NOT_SUPPORTED | It would claim the modem stored APNs which it did not. Matters only for attach APNs (LTE), not this HSPA phone. |
| 129 | SHUTDOWN | Device is shutting down; later commands must answer RADIO_NOT_AVAILABLE. | Yes, on power-off. | `RIL.java` sets the radio state to unavailable regardless of the error. | REQUEST_NOT_SUPPORTED | Success would promise the modem will refuse further commands, which this RIL does not do. TODO: consider mapping it to a radio power off. |
| 130 | GET_RADIO_CAPABILITY | Returns the radio access families supported. | Yes, `GsmCdmaPhone` at startup. | `RIL.java` replaces REQUEST_NOT_SUPPORTED and GENERIC_FAILURE with a static capability built from the preferred-network masks. Android 7 expects this error. | REQUEST_NOT_SUPPORTED | `libril` itself turns a success with empty data into an invalid-response error. A made-up capability could be wrong for this modem. |
| 131 | SET_RADIO_CAPABILITY | Switch the modem's radio capability. ril.h warns it may reset some modems. | Multi-SIM switching only. Not expected on a single-SIM phone. | n/a | REQUEST_NOT_SUPPORTED | Never forward or pretend: a wrong guess could reset the modem. |
| 132 | START_LCE | Start link capacity estimates; the reply is LCE status. | Yes, `Phone` constructor and on radio available. | `Phone` logs "config LCE service failed". | LCE_NOT_SUPPORTED (36), the code ril.h documents | A fake status would claim estimates are coming. |
| 133 | STOP_LCE | Stop LCE. | Paired with 132. | n/a | LCE_NOT_SUPPORTED | As above. |
| 134 | PULL_LCEDATA | Read LCE data. | Only if LCE is running. | n/a | LCE_NOT_SUPPORTED | As above. |
| 135 | GET_ACTIVITY_INFO | Modem sleep/idle/tx/rx times. | Not at startup (caller not traced). | Caller gets no data. | REQUEST_NOT_SUPPORTED | Zeroes would be wrong data. |
| 136 | SET_CARRIER_RESTRICTIONS | Carrier lock list. | Not at startup. | `libril` answers REQUEST_NOT_SUPPORTED itself (needs RIL 14). | never reaches the vendor | n/a |
| 137 | GET_CARRIER_RESTRICTIONS | Reads it. | Not at startup. | same | never reaches the vendor | n/a |

Rule used for the interposer: **an id outside the vendor table is answered with an error code, never success, and never forwarded.** The error codes above are the ones ril.h or `RIL.java` expect for each case.

Prototype: `android/device/samsung/goldenvess3g/ril/ril_interposer.c` (not referenced by `device.mk` or `BoardConfig.mk`). Test: `tools/ril-interposer-test/run-test.sh` (host, fake vendor library written for the test, no Samsung code):
- Ids 1 to 123 reach the vendor library unchanged; 124 to 137 never do and are completed exactly once with an error (TESTED-HOST: PASS).
- With the limit set wrong (200) the same test fails on id 124, so the test does detect a missing filter.
- This proves the filtering logic only. It is not an Android build and says nothing about the real library.

Open points for the interposer: the limit 123 comes from the dump build and must be rechecked on the official library; the exact request/response behaviour of the vendor library for the supported ids is untested.

## 5. Dependencies

### Proprietary libraries (STATIC)
- `libmarvell-ril.so` needs `libstlport` (removed from Android 7), six deprecated `sqlite3_*` functions, `libsecnativefeature` and the Marvell libraries listed in the vendor manifest.
- sqlite: the cm-14.1 `external/sqlite` header still declares `sqlite3_prepare`, and its Android.mk does not define `SQLITE_OMIT_DEPRECATED` (SOURCE). The six functions are very likely exported; confirm with `nm` on a built `libsqlite`.
- libexpat (`XML_Parse`, used by `libsecnativefeature`): `external/expat` is present in cm-14.1 (SOURCE), so resolvable once built.
- `libstlport`: must come from official firmware as a blob (also used by the camera HAL). Until then the RIL cannot load.
- Daemons need `libMILV` and `libwtpsp_ss` (`cploader`, `eeh`), `libwtpsp`, `libparseTim`, `libomission_avoidance` (`atcmdsrv`). All are text-relocation libraries in the dump (small counts, one to two relocations each; platform daemons are exempt from the Android 7 rejection when `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS` is set). See the vendor document.

### Kernel interfaces (SOURCE, Phase 2 tree)
- The telephony drivers come from `drivers/marvell/marvell-telephony`: `cp_load` (cploaddev), `errorhandler` (seh), `citty`, `shmem/msocket` (msocketk), `cidatastub`, `ccinetdev`, `cidatatty`, `diag` (gs_diag), `usim_event`, `hwmap`. All of these built in Phase 2 (20 modules).
- **`gs_modem` resolved:** the string appears only in the USB gadget serial code (`drivers/usb/gadget/pxa910_f_modem.c`, `pxa910_u_serial.c`), not in the telephony drivers and not in any Makefile. It is therefore the USB "diag/modem" gadget function, probably built into the kernel, not a missing telephony module. The earlier worry that a telephony module was missing is withdrawn; whether the stock script's `insmod gs_modem` ever succeeded is not shown.
- Open: module load order and parameters. Which of these load at boot or only through `tel_launch.sh` is only known from the dump's scripts.

### Daemons and scripts (STATIC, dump)
`tel_launch.sh` sets `NVM_ROOT_DIR`, copies default audio calibration files (`audio*.nvm`, calibration XML) from `/system/etc/tel/ttc/` into the NVM area, then starts the composite USB setup. Telephony and call audio are therefore tied together through files in the NVM partition. It also sets `ro.marvell.platform.type TTC_TD`; what that means for this GT-I8200 (an HSPA phone) is not known and I draw no conclusion.

### Modem firmware (UNKNOWN)
The modem image sits in the MODEM partition (community claim: partition 11). `cploader` and `eeh` use `libMILV` to load and validate it (STATIC: `MILVLoadAndValidateImage`). Nothing was obtained or read. Without official firmware nobody can say whether the modem image matches the RIL or whether Android 7 changes anything that matters. NVM (partition 12, CLAIMED) holds calibration data and the IMEI side files; it must never be written from here.

### Other framework needs
- Android 7's `ril.h` struct-size handling (section 2) must match what the Marvell RIL emits for data call lists and signal strength: UNKNOWN.
- Mobile data on Android 7 needs the kernel network features listed in `kernel/android7.config.fragment` (UID routing, netfilter marks and so on) and a separate decision on how to apply them without editing the kernel source: UNKNOWN effort.
- No Marvell RIL class exists in `frameworks/opt/telephony` cm-14.1. The framework talks to the vendor RIL only through the standard interface.

## 6. Realistic assessment by function

"Plausible" means the pieces exist on paper; it is not a prediction that it will work.

| Function | What exists (evidence) | What is unknown | Assessment |
|---|---|---|---|
| SIM detection | Handlers for GET_SIM_STATUS (1), PIN/PUK (2 to 7), SIM_IO (28), IMSI (11) (STATIC) | SIM status structure size vs Android 7; daemon/modem start; `simal` | Plausible after the modem stack starts; unproven. |
| Network registration | Handlers for voice/data registration (20, 21), operator (22), signal (19), radio power (23), network selection (45 to 48), preferred network type (73, 74) (STATIC). Cell info list (109) and initial-attach APN (111) are unsupported, so Android 7's cell info calls will fail harmlessly (SOURCE reasoning) | Modem boot, string formats of the registration answers | Plausible, unproven. |
| Voice calls | Handlers for dial, answer, hang-up, call list, DTMF, mute, conference (STATIC) | Call-audio path through the Marvell audio HAL and NVM files; echo/voice processing blobs; Android 7 audio policy | The riskiest part of voice: signalling may work while audio does not. |
| SMS | Handlers for SEND_SMS (25, 26), acknowledge (37), SIM storage (63, 64), SMSC (100, 101), GSM broadcast (89 to 91) (STATIC) | PDU details | Plausible; likely the first thing to work if registration works. |
| Mobile data | SETUP_DATA_CALL (27), DEACTIVATE (41), DATA_CALL_LIST (57) handlers (STATIC); Android 7 sends 7 strings (SOURCE) | Response structure size vs Android 7's size-based decoding; data interface (`ccinetdev`, `/dev/cci*`) and netd/UID routing on Android 7; kernel options | Highest integration risk of the common functions. |
| Emergency calls | Dial handler only | Emergency number routing, modem behaviour | Cannot be tested safely in any computer-only way. Do not rely on it. |
| LTE, IMS, CDMA, multi-SIM | Marked unsupported or absent | n/a | Not supported. |

Probabilities are not estimated because no data supports a number.

## 7. What a computer can still do, and what it cannot

Can do (no phone, no flashing):
- Rebuild the dependency closure from official firmware once available (libstlport, libMILV and so on).
- Build the interposer with the Android toolchain and run the host test again against the real vendor library's table, read from official firmware.
- Write a host harness that feeds recorded-style requests through `libril` with a fake modem, to exercise the Parcel size checks.
- Check that every blob in the telephony stack resolves its symbols against Android 7 libraries by name (not by signature).

Cannot do:
- Prove that the modem boots, registers, carries calls or data.
- Prove audio during calls.
- Test the real RIL at all (loading it would run vendor code on the host or the phone).

## 8. Go/no-go for any future hardware test of cellular

Not met today. Required, in this order:
1. Official firmware from Samsung, hash-checked and recorded, and the real partition table (not community sizes).
2. The interposer built, the limit re-verified, host test passing against the official library's table.
3. Every telephony blob resolves against Android 7 libraries; `libstlport` and the missing libraries present.
4. A backup plan for the phone's modem, NVM and EFS data (these hold the IMEI and calibration) agreed with the owner **before** any test.
5. Explicit approval from the owner for any phone interaction. This document authorises none.

## 9. Recommendation for cellular

Do not let the cellular unknowns block the first experimental build, but do not promise calls or data. Treat cellular as a separate later milestone whose first target is SIM detection and registration only. If those fail, the realistic fallback is an Android 7 phone with Wi-Fi, Bluetooth and GPS and no mobile service.
