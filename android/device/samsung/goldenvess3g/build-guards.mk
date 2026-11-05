# Hard stops for inputs that must come from VERIFIED sources. Included by Android.mk, i.e. at build time (not at
# `breakfast` time). There is deliberately no override switch: set each value in BoardConfig.mk only when it has a
# verified source, and extract the vendor tree only with vendor/samsung/goldenvess3g/extract-files.sh.
#
# Why: if these are unset the Android build silently falls back to tool defaults (mkbootimg offsets, no image size
# checks, no vendor libraries). Defaults are not evidence about this phone.
_gv_missing :=
$(foreach v,BOARD_KERNEL_BASE BOARD_KERNEL_PAGESIZE BOARD_KERNEL_CMDLINE BOARD_BOOTIMAGE_PARTITION_SIZE \
  BOARD_RECOVERYIMAGE_PARTITION_SIZE BOARD_SYSTEMIMAGE_PARTITION_SIZE BOARD_USERDATAIMAGE_PARTITION_SIZE \
  BOARD_FLASH_BLOCK_SIZE,$(if $(strip $($(v))),,$(eval _gv_missing += $(v))))
ifneq ($(strip $(_gv_missing)),)
$(error goldenvess3g: refusing to build. These BoardConfig values have no verified source yet:$(_gv_missing). \
  See docs/phase-6-first-build-attempt.md. Do not fill them with guesses or community numbers)
endif
ifeq ($(wildcard vendor/samsung/goldenvess3g/goldenvess3g-vendor.mk),)
$(error goldenvess3g: refusing to build. vendor/samsung/goldenvess3g/goldenvess3g-vendor.mk is missing: the proprietary \
  files have not been extracted from verified official firmware (extract-files.sh). The community dump is not accepted)
endif
ifeq ($(wildcard vendor/samsung/goldenvess3g/extraction-report.txt),)
$(error goldenvess3g: refusing to build. vendor/samsung/goldenvess3g/extraction-report.txt (provenance record) is missing)
endif
ifeq ($(strip $(GOLDENVESS3G_KERNEL_DIR)),)
$(error goldenvess3g: refusing to build. GOLDENVESS3G_KERNEL_DIR is not set. Build the kernel out of band with \
  tools/kernel-build/build-golden-kernel.sh and point this variable at a directory with zImage and modules/*.ko)
endif
# Android 7.1.2 init cannot start without SELinux in the kernel (Phase 6; kernel/android7.config.fragment explains).
# The out-of-band kernel build must leave its .config next to zImage. A kernel without SELinux is refused here instead
# of being shipped silently. Running without SELinux would be an explicit owner decision, not a default.
_gv_selinux := $(shell grep -c '^CONFIG_SECURITY_SELINUX=y$$' $(GOLDENVESS3G_KERNEL_DIR)/.config 2>/dev/null)
ifneq ($(_gv_selinux),1)
$(error goldenvess3g: refusing to build. $(GOLDENVESS3G_KERNEL_DIR)/.config is missing or lacks CONFIG_SECURITY_SELINUX=y. \
  See kernel/android7.config.fragment: the policy-version blocker must be resolved first)
endif
