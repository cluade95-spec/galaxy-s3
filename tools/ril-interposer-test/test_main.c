#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <telephony/ril.h>
static int completed[200]; static RIL_Errno err[200];
static void complete(RIL_Token t, RIL_Errno e, void *resp, size_t len) {
    int id = (int)(long)t; completed[id]++; err[id] = e;
}
static void unsol(int u, const void *d, size_t l) {}
static void timed(RIL_TimedCallback cb, void *p, const struct timeval *rt) {}
static void ack(RIL_Token t) {}
int main(int argc, char **argv) {
    void *shim = dlopen(argv[1], RTLD_NOW | RTLD_GLOBAL);
    void *fake = dlopen(argv[2], RTLD_NOW);
    if (!shim || !fake) { fprintf(stderr, "dlopen failed: %s\n", dlerror()); return 2; }
    const RIL_RadioFunctions *(*init)(const struct RIL_Env *, int, char **) = dlsym(shim, "RIL_Init");
    struct RIL_Env env = { complete, unsol, timed, ack };
    const RIL_RadioFunctions *f = init(&env, 0, NULL);
    if (!f) { fprintf(stderr, "RIL_Init returned NULL\n"); return 2; }
    int bad = 0;
    if (f->version != 7) { printf("FAIL version %d\n", f->version); bad++; }
    for (int id = 1; id <= 137; id++) f->onRequest(id, NULL, 0, (RIL_Token)(long)id);
    int *viol = dlsym(fake, "fake_violation"), *maxfwd = dlsym(fake, "fake_forwarded_max"), *calls = dlsym(fake, "fake_calls");
    for (int id = 1; id <= 137; id++) {
        if (completed[id] != 1) { printf("FAIL id %d completed %d times\n", id, completed[id]); bad++; }
        if (id <= 123 && err[id] != RIL_E_SUCCESS) { printf("FAIL id %d changed result\n", id); bad++; }
        if (id >= 124 && err[id] == RIL_E_SUCCESS) { printf("FAIL id %d answered with success\n", id); bad++; }
        if (id >= 124) {
            RIL_Errno want = (id >= 132 && id <= 134) ? RIL_E_LCE_NOT_SUPPORTED : RIL_E_REQUEST_NOT_SUPPORTED;
            if (err[id] != want) { printf("FAIL id %d error %d want %d\n", id, err[id], want); bad++; }
        }
    }
    if (*viol || *maxfwd != 123 || *calls != 123) { printf("FAIL forwarded: violation=%d max=%d calls=%d\n", *viol, *maxfwd, *calls); bad++; }
    printf(bad ? "RESULT: FAIL (%d)\n" : "RESULT: PASS (ids 1-123 forwarded unchanged; 124-137 rejected with errors, none forwarded)\n", bad);
    return bad ? 1 : 0;
}
