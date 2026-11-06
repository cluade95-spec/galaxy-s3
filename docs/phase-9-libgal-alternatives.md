# Phase 9, Part E: alternatives to a `libgal_file` exception

Question: can the project avoid giving any process permission to modify-then-execute pages of the vendor GPU library `libGAL.so` (SELinux `execmod`, plus a linker exception for text relocations)?

Nothing was applied: the broad flag `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS` stays commented out in `BoardConfig.mk` (checked, line 110), the `libgal_file` proposal under `android/device/samsung/goldenvess3g/sepolicy/proposals/` is untouched, and no phone was used.
The analysis ran on the **community dump** of `libGAL.so` (not authenticated Samsung firmware). It is static analysis only: nothing from the library was executed, and no library files were committed.

## Background (from Phases 7 and 8)

Android 7.1.2's linker refuses to load a shared library that has text relocations, unless the platform opts in. Plus SELinux `execmod` is required to relocate a text page and then execute it. `libGAL.so` is the Vivante GPU user-space library for the Marvell GPU; the kernel side (`galcore`) is in the pinned kernel tree.

## New facts from this phase (STATIC)

Analysis of the community `libGAL.so` (ARM, stripped, no `.symtab`):

| Measure | Value |
|---|---|
| Relocation sites inside the executable (read-only) segment | 4,001 |
| of which in `.text` / `.rodata` | 3,631 / 370 |
| What they point at | `.rodata` 2,546; `.text` 751; `.bss` 657; `.data` 47 |
| All sites word-aligned | yes (4,001 of 4,001) |
| pc-relative literal loads found by linear sweep (ARM / Thumb) | 486 / 1 |
| Relocation sites that are the target of such a literal load | 289 of 4,001 |

Interpretation: the library was linked with absolute addresses embedded in code (literal pools and data tables inside the read-only text segment). Only 289 of the 4,001 sites could be tied to a literal load by a linear sweep. The remaining ~3,700 were not classified (the sweep is incomplete, mapping symbols are absent because the file is stripped). This is not a count of instructions that would need rewriting; it is evidence that the pattern is pervasive.

Source availability (STATIC): the pinned kernel contains `drivers/marvell/graphics/galcore_src` (galcore driver, version macros 4.6.9 build 4651, 33 `.c` files, plus 7 user-HAL **headers** in `hal/user`). No user-space `libGAL` sources are in any repository this project has. `external/mesa3d` is in the LineageOS manifest, but no Vivante/etnaviv driver for this GPU is.

## Alternatives

| # | Alternative | Possible? | Notes | Label |
|---|---|---|---|---|
| E1 | Rebuild `libGAL.so` from source with PIC (no text relocations) | **No** | No user-space sources exist in the project. The kernel headers do not contain the library. | STATIC |
| E2 | Binary-patch `libGAL.so` to remove the relocations | **Not realistic** | About 4,000 sites, mostly in unclassified data/literal pools inside a stripped binary; only 289 tied to a literal load. Converting them needs position-independent rewriting of an unknown number of code paths. A wrong edit corrupts a GPU driver silently. Also it modifies a vendor binary whose provenance is unauthenticated. | STATIC |
| E3 | Replace with a different GPU stack: Mesa software rendering (`BOARD_GPU_DRIVERS := swrast`, Gallium softpipe) with generic AOSP `gralloc.default` / `hwcomposer.default` | **Possible in principle; unproven** | `external/mesa3d` at `android-7.1.2_r36` builds a `swrast`-only EGL (confirmed in its `Android.mk`: `-DGALLIUM_SOFTPIPE`; `LOCAL_MODULE := libmesa_egl_gallium`). It has no text-relocation problem and needs no `execmod`. But softpipe is CPU-only: no GPU acceleration, and Android 7.1.2's UI is expected to be slow. It also does not remove the other text-relocation vendor libraries (GPS, codecs, modem; see Phase 8). Performance and whether SurfaceFlinger/system UI are usable were **not tested**. | STATIC; UNRESOLVED on hardware |
| E4 | Narrow, per-library linker exception (exact path) + type-scoped `execmod` (`libgal_file`) | **Yes (the Phase 8 design)** | Works in emulator at the SELinux level (execmod allowed only for `libgal_file`, refused for other labels; 3/3 tests in Phase 8 and in Phase 9 runs C3, A3 to A6). The linker patch (`patches/bionic-libGAL-textrel.patch` rev 2) applies to the cm-14.1 bionic as a check only. | PROVEN (policy, emulator); UNRESOLVED (real library, real linker) |
| E5 | Load the library into anonymous memory, relocate there, then make it executable | Not recommended | This avoids `execmod` on a file but needs a different permission (`execmem`), which is usually a broader grant on the process, and it needs a custom loader. Not prototyped. | STATIC reasoning, untested |
| E6 | Broad flag (`TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS`) | Rejected | Weakens the platform for every library. Stays off. | policy decision |

## Is a narrow exception unavoidable?

- **For accelerated graphics with the vendor GPU stack: yes, unavoidable** (E1 and E2 are not available; E5 trades one exception for a broader one). **Conclusion label: static analysis, not hardware-proven.**
- **For a first-boot ROM that does not need acceleration: avoidable** if E3 is accepted, at the cost of performance and the untested Mesa integration.
- **Which of these the project chooses is an owner decision.** The decision on hold is therefore "unresolved", not "unavoidable", because E3 has not been evaluated on hardware.

## Security implications of E4 (if chosen)

- Granted permission: `execmod` on `libgal_file` only (one file, `/system/lib/libGAL.so`), plus `execute` and read. The platform `neverallow` for `execmod` gets one named exemption, and guard assertions (`guards/libgal_file_guards.te`) restrict who may write or relabel the type.
- What `execmod` allows: a domain may map that file privately, write its text pages (relocation), and then execute them. In a process that is compromised, this is code modification of **that mapping only**; the file on disk is unchanged. It does not allow executing arbitrary anonymous memory.
- Memory cost: about 464 KiB of private (non-shared) text for every process that maps the library (Phase 7 measurement).
- Fail-closed property: any domain not listed gets a denial instead of a wider grant.

Affected processes in the Phase 8 proposal (taken from the dependency graph of the community dump, **unconfirmed on a boot**): `surfaceflinger`, `bootanim`, `mediaserver`, and the app domains `untrusted_app`, `platform_app`, `system_app`, `priv_app`. The app domains are the part to question: granting `execmod` to `untrusted_app` on this file means any ordinary app that links GL can modify its private copy of the library text. Whether that is necessary (apps normally reach GL through the EGL loader in their own process, so they probably map the library) is UNRESOLVED until a boot shows which domains actually load it.

## Other text-relocation libraries (carried over from Phase 8)

With the broad flag off, the linker also refuses GPS, `libgpucsc`, `libacdapi_clb`, codecs and modem libraries. E4 does not help them. A first build must either omit those features or give each its own reviewed exception. Not re-examined in Phase 9.

## Decision for this part

**libGAL exception: unresolved, leaning unavoidable for GPU acceleration.** The software-rendering alternative (E3) is the only route that avoids the exception and has not been tested. See `phase-9-final-recommendation.md`.
