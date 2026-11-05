# sepolicy: intentionally empty (TODO)

Phase 6 facts that any policy work must start from (SOURCE: LineageOS cm-14.1 `system/sepolicy` @ 83840c7, `system/core/init`;
kernel config and source at the pinned commit):

1. **Text relocations.** With `TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS := true` (set), `domain.te` relaxes its `execmod`
   neverallow rules for `system_file` and for non-app domains. Device policy would then have to grant `execmod` on
   `system_file` to the domains that load `libGAL.so`, `libMILV` and so on. A separate file type for libGAL is not an option:
   the neverallow still covers every new `file_type`. This is a genuine weakening and is NOT written yet.
2. **Kernel and policy version.** The kernel's SELinux accepts policy versions up to 26 and has no ioctl extended-permission
   (`xperm`) code, but Android 7.1.2's policy is built at version 30 and uses `allowxperm`. See
   `../kernel/android7.config.fragment`. Until that is resolved, no policy for this device can be loaded.
3. Nothing here may be copied from the SM-T110 port: that port runs with SELinux disabled.
