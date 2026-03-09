TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = TKVideoCleaner

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TKVideoCleaner

# 核心编译文件
TKVideoCleaner_FILES = main.m TKAppViewController.m
# 必须引入的 iOS 系统底层框架
TKVideoCleaner_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI
TKVideoCleaner_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
