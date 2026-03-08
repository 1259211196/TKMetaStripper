TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = TikTok Aweme

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TKMetaStripper

TKMetaStripper_FILES = Tweak.x TKEnvManager.m TKVideoCleaner.m
TKMetaStripper_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
