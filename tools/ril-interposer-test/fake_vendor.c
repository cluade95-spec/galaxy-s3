/* FAKE vendor RIL for the host test. Mimics only the one risky property: ids above 123 are forbidden. */
#include <stddef.h>
#include <telephony/ril.h>
static const struct RIL_Env *env;
int fake_forwarded_max = 0;
int fake_violation = 0;
int fake_calls = 0;
static void on_request(int request, void *data, size_t datalen, RIL_Token t) {
    fake_calls++;
    if (request > fake_forwarded_max) fake_forwarded_max = request;
    if (request > 123 || request < 1) fake_violation = 1;
    env->OnRequestComplete(t, RIL_E_SUCCESS, NULL, 0);
}
static RIL_RadioState on_state(void) { return RADIO_STATE_UNAVAILABLE; }
static int supports(int r) { return 1; }
static void cancel(RIL_Token t) {}
static const char *get_version(void) { return "fake"; }
static const RIL_RadioFunctions f = { 7, on_request, on_state, supports, cancel, get_version };
const RIL_RadioFunctions *RIL_Init(const struct RIL_Env *e, int argc, char **argv) { env = e; return &f; }
