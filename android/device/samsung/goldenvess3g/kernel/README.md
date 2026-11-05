# Kernel integration notes (GT-I8200)

Base: `Koloses/kernel_i8200` @ `44afe4cf6023bf39c18bad72185003a40915fad2` (provisional, see Phase 2). The source is
**not modified** by this skeleton.

Verified (docs/phase-2-kernel-build.md): builds with AOSP `arm-eabi-4.6` (GCC 4.6.x-google 20120106) from
`pxa986_golden_rev02_defconfig`; 20 modules build. Use `tools/kernel-build/build-golden-kernel.sh` as the reference.

Open integration questions (TODO, not guessed):

1. **Toolchain wiring.** Lineage 14.1's `vendor/cm/build/tasks/kernel.mk` defaults to `arm-linux-androidkernel-`. It exposes
   `TARGET_KERNEL_CROSS_COMPILE_PREFIX`, `KERNEL_TOOLCHAIN` (path) and `KERNEL_TOOLCHAIN_PREFIX` (verified variable names).
   The pinned `arm-eabi-4.6` must be selected; compilers newer than 4.6 are untested on this kernel.
2. **Host-side build problems.** Perl 5.22+ rejects `kernel/timeconst.pl` (a run-time shim exists in
   `tools/kernel-build/perl-shim.sh`); the committed Samsung build leftovers must be cleaned in a copy
   (`make mrproper`) before an out-of-tree build. A Lineage build host with an older Perl avoids the first.
3. **Config changes.** Lineage's `TARGET_KERNEL_ADDITIONAL_CONFIG` expects the extra defconfig *inside the kernel tree*,
   which would modify the source. Choose a mechanism that keeps the source untouched (for example a wrapper that applies
   `scripts/config` to the output `.config`). `android7.config.fragment` lists the candidate options.
4. **Samsung production options.** Samsung's shipped kernel enables `CONFIG_SAMSUNG_PRODUCT_SHIP` and four
   `CONFIG_SEC_RESTRICT_*` options that restrict root and UID changes. The plain defconfig has them off. For a custom ROM
   the plain defconfig (Build A in Phase 2) is the expected starting point. Decision pending.
