# libshim_goldenvess3g - UNBUILT. See ../README.md. Do not add to PRODUCT_PACKAGES before the first build test.
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := libshim_goldenvess3g
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := \
    libutils_vectorimpl.cpp \
    refbase_moveref.cpp \
    binder_getcallingpid.c
# camera_params_generated.cpp is produced by tools/vendor/gen-camera-shim.py from the OFFICIAL firmware's
# libcamera_client.so and is not part of the repository.
ifneq ($(wildcard $(LOCAL_PATH)/camera_params_generated.cpp),)
LOCAL_SRC_FILES += camera_params_generated.cpp
endif
LOCAL_SHARED_LIBRARIES := libbinder libutils
LOCAL_CFLAGS := -Wall -Wextra -Werror
include $(BUILD_SHARED_LIBRARY)
