// RefBase::moveReferences no longer exists in Android 7.  UNBUILT / UNTESTED.
// ASSUMPTION (unverified): the stock function only acted when reference debugging was compiled in, so a no-op is
// enough. Verify against the Android 4.2 libutils source before relying on it.
extern "C" void goldenvess3g_moveReferences(void* dst, const void* src, unsigned int n, const void* caster)
    __asm__("_ZN7android7RefBase14moveReferencesEPvPKvjRKNS_22ReferenceConverterBaseE");
extern "C" void goldenvess3g_moveReferences(void*, const void*, unsigned int, const void*) {}
