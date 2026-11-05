// Empty stubs for virtual slots that Android 7's libutils no longer has.  UNBUILT / UNTESTED.
// The symbol names are taken from the undefined-symbol list of the stock camera HAL (exact, verified).
// Member functions are given as plain functions with asm labels; the implicit `this` is ignored.
#define VI(n) \
    extern "C" void goldenvess3g_vi##n() __asm__("_ZN7android10VectorImpl19reservedVectorImpl" #n "Ev"); \
    extern "C" void goldenvess3g_vi##n() {}
#define SVI(n) \
    extern "C" void goldenvess3g_svi##n() __asm__("_ZN7android16SortedVectorImpl25reservedSortedVectorImpl" #n "Ev"); \
    extern "C" void goldenvess3g_svi##n() {}

VI(1) VI(2) VI(3) VI(4) VI(5) VI(6) VI(7) VI(8)
SVI(1) SVI(2) SVI(3) SVI(4) SVI(5) SVI(6) SVI(7) SVI(8)
