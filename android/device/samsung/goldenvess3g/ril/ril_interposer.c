/*
 * goldenvess3g RIL interposer (PROTOTYPE, Phase 5). UNBUILT FOR ANDROID, UNTESTED ON HARDWARE.
 * Not referenced by device.mk or BoardConfig.mk on purpose.
 *
 * Why it exists (evidence, see docs/phase-5-cellular-feasibility.md):
 *  - Android 7.1.2's libril forwards request ids 1..137 to the vendor RIL's onRequest().
 *  - The community-dump libmarvell-ril.so (STATIC reading) indexes a 124-entry table (ids 0..123)
 *    with no upper bound check for ids below 500. Ids 124..137 read data that is not table data.
 *  - Returning RIL_E_SUCCESS for them would be wrong: callers parse a response (hardware config,
 *    radio capability, LCE status) that this code cannot produce, so every id above the vendor limit is
 *    answered with an ERROR, never with success.
 *
 * Wiring (TODO, needs a real build): rild.libpath=/system/lib/libril-goldenvess3g.so, vendor RIL kept
 * at VENDOR_RIL_PATH. Re-check VENDOR_LAST_REQUEST_ID against the OFFICIAL firmware's library first.
 */
#include <dlfcn.h>
#include <string.h>
#include <telephony/ril.h>

#ifndef VENDOR_RIL_PATH
#define VENDOR_RIL_PATH "/system/lib/libmarvell-ril.so"
#endif
/* STATIC finding from the community dump: table valid for ids 0..123. TODO verify on official firmware. */
#ifndef VENDOR_LAST_REQUEST_ID
#define VENDOR_LAST_REQUEST_ID 123
#endif

#ifdef __ANDROID__
#include <android/log.h>
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, "RILShim", __VA_ARGS__)
#else
#include <stdio.h>
#define LOGW(...) do { fprintf(stderr, "RILShim: "); fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

static const struct RIL_Env *s_env;
static RIL_RadioFunctions s_vendor;  /* copy of what the vendor library returned */
static RIL_RadioFunctions s_shim;

/* Error returned for ids the vendor library cannot handle. Never RIL_E_SUCCESS. */
static RIL_Errno reject_code(int request) {
    switch (request) {
        case RIL_REQUEST_START_LCE:
        case RIL_REQUEST_STOP_LCE:
        case RIL_REQUEST_PULL_LCEDATA:
            return RIL_E_LCE_NOT_SUPPORTED;      /* the code ril.h documents for LCE */
        default:
            return RIL_E_REQUEST_NOT_SUPPORTED;  /* RIL.java accepts this for GET_RADIO_CAPABILITY */
    }
}

static void shim_onRequest(int request, void *data, size_t datalen, RIL_Token t) {
    if (request > VENDOR_LAST_REQUEST_ID || request < 1) {
        LOGW("request %d is outside the vendor RIL table (1..%d): rejected, not forwarded",
             request, VENDOR_LAST_REQUEST_ID);
        s_env->OnRequestComplete(t, reject_code(request), NULL, 0);
        return;
    }
    s_vendor.onRequest(request, data, datalen, t);
}

const RIL_RadioFunctions *RIL_Init(const struct RIL_Env *env, int argc, char **argv) {
    void *h = dlopen(VENDOR_RIL_PATH, RTLD_NOW);
    if (!h) { LOGW("cannot load %s: %s", VENDOR_RIL_PATH, dlerror()); return NULL; }
    const RIL_RadioFunctions *(*vinit)(const struct RIL_Env *, int, char **) =
        (const RIL_RadioFunctions *(*)(const struct RIL_Env *, int, char **))dlsym(h, "RIL_Init");
    if (!vinit) { LOGW("RIL_Init not found in %s", VENDOR_RIL_PATH); return NULL; }
    s_env = env;
    const RIL_RadioFunctions *v = vinit(env, argc, argv);
    if (!v) return NULL;
    s_vendor = *v;
    s_shim = *v;               /* version, onStateRequest, supports, onCancel, getVersion pass through */
    s_shim.onRequest = shim_onRequest;
    return &s_shim;
}
