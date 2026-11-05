# Compatibility shims for the stock closed libraries (UNBUILT, UNTESTED)

Purpose: satisfy symbol and ABI differences between the Android 4.2 vendor libraries and Android 7.1.2. Each entry below
states whether the *need* is verified and whether the *fix* has been tested. **Nothing here has been compiled for ARM,
linked into an image or run.** Host syntax checks only.

| Shim | Need | Fix status |
|---|---|---|
| `VectorImpl::reservedVectorImpl1-8`, `SortedVectorImpl::reservedSortedVectorImpl1-8` (`libutils_vectorimpl.cpp`) | VERIFIED: imported by `camera.mrvl.so`, `libwvm.so`, `libdrmwvmplugin.so`, `libmrvlpreprocessing.so`, `libFileMonitorService.so` and others; absent from Android 7's `libutils` (cm-14.1 `system/core`). | Empty stubs. ASSUMPTION (unverified): the reserved slots were last in the stock vtable, so earlier slot indices are unchanged. Must be checked against the 4.2 header. |
| `RefBase::moveReferences` (`refbase_moveref.cpp`) | VERIFIED: imported by `camera.mrvl.so`; only a comment remains in Android 7's `RefBase.h`. | No-op. ASSUMPTION (unverified): the stock function only did work when reference debugging was compiled in. |
| `IPCThreadState::getCallingPid()` non-const (`binder_getcallingpid.c`) | VERIFIED: imported by `gralloc.mrvl.so` (Phase 3). Android 7 exports only the `const` form. Same need as the SM-T110 port. | Forwarder written from the verified symbol names. Must be preloaded into every process that loads gralloc (surfaceflinger, mediaserver, cameraserver, zygote). |
| `CameraParameters::*` constants (generated) | VERIFIED: 25 constants imported by `camera.mrvl.so` are not defined in cm-14.1 `CameraParameters.cpp` (list in `camera_params_symbols.txt`). | **Generator only** (`tools/vendor/gen-camera-shim.py`). The values must be read from the official firmware's `libcamera_client.so`; they are deliberately NOT generated from the rooted community dump. |
| `IMemoryHeap::~IMemoryHeap` D0/D1/D2 and virtual thunks | VERIFIED: imported by `camera.mrvl.so`; Android 7's `IMemoryHeap` has no out-of-line destructor. | **NOT PROVIDED.** Correct implementation depends on the class's virtual inheritance and vtable in Android 7; needs a build tree to examine. |
| `libstlport.so` | VERIFIED: needed by 8 stock files incl. `libmarvell-ril.so`; not in Android 7. | Not a shim: ship the stock library from official firmware (vendor plan R4). |

Wiring plan (not done): build `libshim_goldenvess3g.so` into `/system/lib`, then add it to `LD_PRELOAD` for the services
above. No `patchelf`-style rewriting of the closed libraries is planned.
