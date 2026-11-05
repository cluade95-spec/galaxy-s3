# GT-I8200 (goldenvess3g) BoardConfig - SKELETON, NOT BUILDABLE.
# The build will stop at the TODO(...) items below on purpose: they need facts that only the stock boot image,
# the partition table or the official firmware can give. Labels: VERIFIED / DERIVED / CLAIMED / DECISION / TODO.
# (Comments sit on their own lines on purpose: trailing comments leave spaces in make values.)

DEVICE_PATH := device/samsung/goldenvess3g

# ---------------------------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------------------------
TARGET_ARCH := arm
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
# DERIVED: stock vendor libraries carry ARM attributes Tag_CPU_arch v7, FP VFPv3, Advanced SIMD NEONv1; the kernel
# builds with CONFIG_NEON=y, CONFIG_VFPv3=y.
TARGET_ARCH_VARIANT := armv7-a-neon
# TODO(cpu variant): generic is used because the core is not established. Community trees say cortex-a9 and the kernel
# also has a PJ4B ("__v7_pj4b_proc_info") entry. Do not set cortex-a9 without evidence.
TARGET_CPU_VARIANT := generic
# VERIFIED: CONFIG_SMP=y, CONFIG_NR_CPUS=2 in pxa986_golden_rev02_defconfig
TARGET_CPU_SMP := true

# CLAIMED: the community stock init sets ro.board.platform "mrvl".
TARGET_BOARD_PLATFORM := mrvl
# TODO(bootloader board name): community trees use PXA986 but the kernel machine name is "PXA988". Not set until the stock
# build.prop (ro.product.board) is read.
# TARGET_BOOTLOADER_BOARD_NAME :=

# DECISION: this project builds neither a bootloader nor a radio image. The modem image stays in the MODEM partition.
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# DERIVED: device codename is shared with GT-I8200Q (same codename in the Play device list), so this assert alone
# cannot tell a GT-I8200 from a GT-I8200Q.
# TODO(model assert): add a ro.product.model == GT-I8200 check to the installer once its format is decided.
TARGET_OTA_ASSERT_DEVICE := goldenvess3g

# ---------------------------------------------------------------------------------------------
# Kernel   (VERIFIED in docs/phase-2-kernel-build.md)
# ---------------------------------------------------------------------------------------------
# Pinned in local_manifest.xml: Koloses/kernel_i8200 @ 44afe4cf6023bf39c18bad72185003a40915fad2, tree 0eebf6f9...
TARGET_KERNEL_SOURCE := kernel/samsung/goldenvess3g
# Builds with the original toolchain; arch/arm/configs/pxa986_golden_rev02_defconfig matches Samsung's own leftover config.
TARGET_KERNEL_CONFIG := pxa986_golden_rev02_defconfig
TARGET_KERNEL_ARCH := arm
BOARD_KERNEL_IMAGE_NAME := zImage
# VERIFIED: the kernel builds with AOSP arm-eabi-4.6 (GCC 4.6.x-google 20120106), pinned in local_manifest.xml.
# TODO(toolchain wiring): Lineage 14.1 defaults to arm-linux-androidkernel-; wire KERNEL_TOOLCHAIN / prefix to the pinned
#   arm-eabi-4.6 (see kernel/README.md). Newer compilers have NOT been tested on this kernel.
TARGET_KERNEL_CROSS_COMPILE_PREFIX := arm-eabi-
# TODO(kernel options for Android 7): UID-range routing patch, netfilter mark/connmark modules, SELinux decision,
#   removal of Samsung SEC_RESTRICT_* options. Listed in kernel/android7.config.fragment. The kernel source is NOT
#   modified by this skeleton; changes will be carried as separate, recorded patches.

# ---------------------------------------------------------------------------------------------
# Boot image  (NOT filled in: no verified values)
# ---------------------------------------------------------------------------------------------
# TODO(boot header): BOARD_KERNEL_BASE, BOARD_KERNEL_PAGESIZE, ramdisk offset, tags offset and the command line must be
#   read from the STOCK boot image. Community values (base 0x10000000, page size 2048) are consistent across trees but
#   unverified; the ramdisk offset conflicts between trees (0x01000000 vs 0x11000000).
#   WARNING: if left unset, mkbootimg falls back to its own defaults (base 0x10000000, ramdisk offset 0x01000000,
#   page size 2048). That is a tool default, NOT evidence about this phone.
# BOARD_KERNEL_BASE :=
# BOARD_KERNEL_PAGESIZE :=
# BOARD_KERNEL_CMDLINE :=
# BOARD_MKBOOTIMG_ARGS :=
# VERIFIED: no device tree (board-file kernel, CONFIG_USE_OF not set), so no dt.img / --dt.

# ---------------------------------------------------------------------------------------------
# Partitions and filesystems  (NOT filled in: no verified sizes)
# ---------------------------------------------------------------------------------------------
# TODO(partition sizes): BOARD_BOOTIMAGE_PARTITION_SIZE, BOARD_RECOVERYIMAGE_PARTITION_SIZE,
#   BOARD_SYSTEMIMAGE_PARTITION_SIZE, BOARD_USERDATAIMAGE_PARTITION_SIZE, BOARD_CACHEIMAGE_PARTITION_SIZE,
#   BOARD_FLASH_BLOCK_SIZE. Community values conflict (boot 12/16/64 MiB, system 1438/1521/6084 MiB). Read the PIT or a
#   read-only partition listing of the stock firmware/phone.
# BOARD_BOOTIMAGE_PARTITION_SIZE :=
# BOARD_SYSTEMIMAGE_PARTITION_SIZE :=
# BOARD_USERDATAIMAGE_PARTITION_SIZE :=
# BOARD_CACHEIMAGE_PARTITION_SIZE :=
# BOARD_FLASH_BLOCK_SIZE :=
# CLAIMED: community fstab and TWRP trees use ext4 for system, cache and data (by-name SYSTEM/CACHE/USER).
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
# DECISION: no recovery image is built in this project phase.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.pxa988

# ---------------------------------------------------------------------------------------------
# Android 7 loader requirements for the stock closed libraries (VERIFIED in docs/phase-3, phase-4)
# ---------------------------------------------------------------------------------------------
# 81 stock libraries have text relocations, including libGAL.so (GPU), gps.default.so and the modem loader libraries.
TARGET_NEEDS_PLATFORM_TEXT_RELOCATIONS := true
# TODO(libGAL exception): apps (SystemUI) load libGAL.so; the SM-T110 port patches bionic for it. Re-apply and re-verify
#   for this device (docs/phase-4, vendor remediation plan R2).
# TODO(non-PIE): bin/rtccd2 and bin/STUpdateTool_V4_4R are not position independent and are refused by Android 7's
#   linker. Deferred, not allow-listed (plan R1).

# ---------------------------------------------------------------------------------------------
# Graphics (DERIVED from the stock library names and Android 7 Loader.cpp)
# ---------------------------------------------------------------------------------------------
# TODO(graphics shims): HWC 1.x layout (100-byte layer record), buffer-queue and gralloc binder symbol shims from the
#   SM-T110 work must be re-verified and applied (docs/phase-1, phase-4 plan R6). Not applied here.

# ---------------------------------------------------------------------------------------------
# Wi-Fi  (VERIFIED chip family: Marvell 88W8787 on SDIO; LineageOS hardware/marvell/wlan exists on cm-14.1)
# ---------------------------------------------------------------------------------------------
BOARD_HAVE_MARVELL_WIFI := true
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mrvl
# TODO(hostapd): soft-AP uses the same private library in community trees; untested.
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mrvl
# CLAIMED: community trees pass firmware names through /proc/mwlan/config; the kernel driver does create mwlan/config
# (VERIFIED in moal_proc.c). TODO(wifi firmware path): confirm the exact value from stock firmware or a hardware test.
# WIFI_DRIVER_FW_PATH_PARAM := "/proc/mwlan/config"
# WIFI_DRIVER_FW_PATH_STA :=
# WIFI_DRIVER_FW_PATH_AP :=
# WIFI_DRIVER_FW_PATH_P2P :=
# The community sd8777 firmware names are a TABLET value and are deliberately NOT used.

# ---------------------------------------------------------------------------------------------
# Bluetooth  (VERIFIED chip: same 88W8787 combo; hardware/marvell/bt exists on cm-14.1)
# ---------------------------------------------------------------------------------------------
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_MRVL := true
# TODO(bdroid buildcfg): Bluedroid vendor include dir is not set; the community bdroid_buildcfg.h was not audited
#   for Android 7 (BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR).

# ---------------------------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------------------------
# VERIFIED (cm-14.1 frameworks/av): the legacy audio policy path still exists. The stock audio HAL reports device
# version 2.0, which equals Android 7's minimum. DECISION PENDING: use the stock audio_policy.mrvl.so (legacy) or the
# default policy with configs/audio_policy.conf.
# TODO(audio policy): decide, then set USE_LEGACY_AUDIO_POLICY := 1 if the legacy path is chosen.
# USE_LEGACY_AUDIO_POLICY := 1
# Not set: BOARD_USES_ALSA_AUDIO / BOARD_HAVE_PRE_KITKAT_AUDIO_BLOB (CM11/12-era flags from community trees; not
# evidence for Lineage 14.1).

# ---------------------------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------------------------
# TODO(camera): stock HAL is HAL1 (module API 1.0), which Android 7 still runs, but it needs the shim work in
#   plan R5. USE_CAMERA_STUB is NOT set: a stub would hide the problem rather than solve it.

# ---------------------------------------------------------------------------------------------
# Telephony  (BLOCKED, see docs/phase-4-cellular-investigation.md)
# ---------------------------------------------------------------------------------------------
# TODO(ril): no BOARD_RIL_CLASS and no rild library path is set. Nothing in the evidence shows the closed Marvell RIL
#   works under Android 7.

# ---------------------------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------------------------
# TODO(sepolicy): the stock kernel has no SELinux. Policy and kernel decision pending (kernel/android7.config.fragment).
# BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
