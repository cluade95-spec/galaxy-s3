# PROTOTYPE. Not included by device.mk. TODO: wire up only after the open items in
# docs/phase-5-cellular-feasibility.md are resolved.
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := libril-goldenvess3g
LOCAL_MODULE_OWNER := samsung
LOCAL_SRC_FILES := ril_interposer.c
LOCAL_CFLAGS := -DRIL_SHLIB
LOCAL_SHARED_LIBRARIES := liblog libdl
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)
