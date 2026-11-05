# GT-I8200 (goldenvess3g) device definitions - SKELETON.
# Only items with evidence are active. Everything else is a TODO comment, not a guess.

LOCAL_PATH := device/samsung/goldenvess3g

# ---- Boot-time files -------------------------------------------------------------------------
# fstab/rc/ueventd are ports of the community-extracted stock ramdisk files (CLAIMED origin). See each file header.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.pxa988:root/fstab.pxa988 \
    $(LOCAL_PATH)/rootdir/etc/init.pxa988.rc:root/init.pxa988.rc \
    $(LOCAL_PATH)/rootdir/etc/init.pxa988.tel.rc:root/init.pxa988.tel.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.pxa988.rc:root/ueventd.pxa988.rc
# Note: init loads init.<ro.hardware>.rc.  DERIVED: ro.hardware should be "pxa988" (kernel machine name "PXA988"
# appears in /proc/cpuinfo, and the stock files are named *.pxa988.*).  TODO(ro.hardware): confirm against the stock
# boot command line, which the bootloader supplies.

# ---- Features declared by the STOCK firmware (CLAIMED: from the community /system dump permission files) -------
# Not declared by stock: light sensor, NFC, barometer.  Do not add them without evidence.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.camera.front.xml:system/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:system/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:system/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:system/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:system/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:system/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml
# TODO(wifi/bluetooth/telephony features): standard Lineage telephony and Wi-Fi/Bluetooth permission files come from
#   the inherited phone product. Telephony stays BLOCKED, see docs/phase-4-cellular-investigation.md.

# ---- Audio -------------------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio_policy.conf:system/etc/audio_policy.conf
PRODUCT_PACKAGES += \
    audio.a2dp.default \
    audio.usb.default \
    audio.r_submix.default \
    libaudio-resampler
# TODO(audio policy): see BoardConfig.mk (USE_LEGACY_AUDIO_POLICY decision).

# ---- Charger  [DECISION] --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    charger \
    charger_res_images

# ---- Graphics --------------------------------------------------------------------------------
# VERIFIED (cm-14.1 Loader.cpp): Android 7 finds libEGL_*.so / libGLESv1_CM_*.so / libGLESv2_*.so in /system/lib/egl
# by pattern, so the stock names (…_MRVL.so) need no egl.cfg.  The stock software GLES (libGLES_android.so from
# Android 4.2) must NOT be shipped.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.opengles.version=131072
# ^ GLES 2.0 (0x20000).  VERIFIED: GC1000 stack is GLES 2.0 (Vivante libGLESv2_MRVL, no Vulkan); stock init sets 131072.
# TODO(graphics quirks): ro.bq.gpu_to_cpu_unsupported, ro.zygote.disable_gl_preload, debug.hwui.partial_updates,
#   dalvik heap values are candidates from other devices; add only after a hardware test shows they are needed.

# ---- Shims (UNBUILT, see shims/README.md) ----------------------------------------------------
# PRODUCT_PACKAGES += libshim_goldenvess3g     # TODO(enable after the first build test)

# ---- Wi-Fi / Bluetooth ------------------------------------------------------------------------
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0
# ^ CLAIMED: stock init sets wifi.interface wlan0 and wifidirect.interface p2p0.
# TODO(wifi firmware and MAC): sd8787_uapsta.bin / w8787_wlan_SDIO_bt_SDIO.bin come from the vendor manifest.

# ---- NFC ---------------------------------------------------------------------------------------
# DERIVED: no NFC hardware (no NFC HAL, firmware or permission file in the GT-I8200 dump). No NFC packages, and NOT the
# ro.stollmann.nfc.* property that appears in the community ramdisk (copied from a Marvell reference board).

# Kernel modules from the out-of-band kernel build (see BoardConfig.mk, kernel section). Not committed: the directory is
# outside the repository and supplied by the builder. Module vermagic must match the kernel image they ship with.
ifneq ($(strip $(GOLDENVESS3G_KERNEL_DIR)),)
PRODUCT_COPY_FILES += $(foreach m,$(wildcard $(GOLDENVESS3G_KERNEL_DIR)/modules/*.ko),$(m):system/lib/modules/$(notdir $(m)))
endif
