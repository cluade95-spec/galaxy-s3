/* Forwarder for the non-const IPCThreadState::getCallingPid() that the stock gralloc imports.  UNBUILT / UNTESTED.
 * Android 7 exports only the const-qualified form (_ZNK...).  Both take the same single `this` argument, so the old
 * name can simply call the new one.  Verified need: nm -D --undefined-only gralloc.mrvl.so (Phase 3).
 * The SM-T110 port needed the same forwarder (idea credited; code written from the verified symbol names). */
extern int goldenvess3g_getCallingPid_new(const void *self)
    __asm__("_ZNK7android14IPCThreadState13getCallingPidEv");

int goldenvess3g_getCallingPid_old(const void *self)
    __asm__("_ZN7android14IPCThreadState13getCallingPidEv");

int goldenvess3g_getCallingPid_old(const void *self)
{
    return goldenvess3g_getCallingPid_new(self);
}
