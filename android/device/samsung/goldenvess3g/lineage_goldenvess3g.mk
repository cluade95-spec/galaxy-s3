# GT-I8200 (goldenvess3g) LineageOS 14.1 product - SKELETON.
# Status labels: VERIFIED / DERIVED / CLAIMED / DECISION / TODO (see android/README.md).

# This is a phone: inherit the phone product, not a tablet one.  [DECISION]
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/cm/config/common_full_phone.mk)

# Device configuration
$(call inherit-product, device/samsung/goldenvess3g/device.mk)

# Vendor (proprietary) files, only if extracted from VERIFIED official firmware. See vendor/samsung/goldenvess3g.
$(call inherit-product-if-exists, vendor/samsung/goldenvess3g/goldenvess3g-vendor.mk)

PRODUCT_NAME := lineage_goldenvess3g
PRODUCT_DEVICE := goldenvess3g
PRODUCT_BRAND := samsung
PRODUCT_MANUFACTURER := samsung
# VERIFIED: model string of the target device
PRODUCT_MODEL := GT-I8200
PRODUCT_RELEASE_NAME := GT-I8200

# Panel is 480x800.  VERIFIED: arch/arm/mach-mmp/onboard/board-golden-display.c (xres 480, yres 800)
TARGET_SCREEN_WIDTH := 480
TARGET_SCREEN_HEIGHT := 800

# TODO(density): ro.sf.lcd_density / PRODUCT_AAPT_PREF_CONFIG are NOT set.
#   Evidence so far: panel is 52 x 86 mm (kernel) => about 234 dpi along the width (DERIVED).
#   Do not copy the SM-T110 tablet value (160). Decide after reading the stock build.prop.
