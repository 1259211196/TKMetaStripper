# 1. 设定目标 SDK 和最低兼容 iOS 版本
# TrollStore 主要支持 iOS 14.0 到 iOS 17.0。设定 14.0 可以确保向下兼容 iPhone X 的老系统
TARGET := iphone:clang:latest:14.0

# 2. 核心架构设定 (必须同时包含这两项)
# arm64  -> 对应 iPhone X (A11 芯片) 及更老机型
# arm64e -> 对应 iPhone XS (A12 芯片) 到 iPhone 15，支持 PAC (指针验证)
ARCHS = arm64 arm64e

# 3. 目标进程名 (虽然是注入 IPA，但习惯上保留)
INSTALL_TARGET_PROCESSES = TikTok

# 4. 项目名称
TWEAK_NAME = TKMetaStripper

# 5. 需要编译的源文件
TKMetaStripper_FILES = Tweak.x TKEnvManager.m TKVideoCleaner.m

# 6. 必须链接的系统原生框架 (非常重要，否则编译会报错找不到类)
TKMetaStripper_FRAMEWORKS = Foundation UIKit Photos AVFoundation CoreLocation

# 7. 开启 ARC (自动内存管理)
TKMetaStripper_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
