TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TKVideoCleaner

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TKVideoCleaner

TKVideoCleaner_FILES = main.m TKAppViewController.m
TKVideoCleaner_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI
TKVideoCleaner_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
# 1. 告诉 Theos 编译这台新发动机的 Swift 代码
V12_SWIFT_FILES += TKVisualForge/Sources/TKVisualForge/VisualForgeEngine.swift

# 2. 告诉 Theos 将编译好的 GPU 着色器放进插件包里
V12_COPY_FILES = $(THEOS_OBJ_DIR)/default.metallib

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk

# ==========================================
# 🌟 核心魔法：自定义 Metal 编译管线
# ==========================================
internal-stage::
	@echo "🔥 正在锻造 GPU 视觉重构核武器..."
	@xcrun -sdk iphoneos metal -c TKVisualForge/Sources/TKVisualForge/CoreShaders.metal -o $(THEOS_OBJ_DIR)/CoreShaders.air
	@xcrun -sdk iphoneos metallib $(THEOS_OBJ_DIR)/CoreShaders.air -o $(THEOS_OBJ_DIR)/default.metallib
	@mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support/V12/
	@cp $(THEOS_OBJ_DIR)/default.metallib $(THEOS_STAGING_DIR)/Library/Application\ Support/V12/default.metallib
