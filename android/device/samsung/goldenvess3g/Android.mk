# goldenvess3g device Android.mk. Pulls in the build guards, then the device's own module makefiles.
LOCAL_PATH := $(call my-dir)
ifeq ($(TARGET_DEVICE),goldenvess3g)
include $(LOCAL_PATH)/build-guards.mk
endif
