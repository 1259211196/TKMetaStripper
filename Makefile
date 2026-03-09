TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TKVideoCleaner

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TKVideoCleaner

TKVideoCleaner_FILES = main.m TKAppViewController.m
TKVideoCleaner_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI
TKVideoCleaner_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
