TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TKVideoCleaner

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TKVideoCleaner

TKVideoCleaner_FILES = main.m TKAppViewController.m
TKVideoCleaner_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI
TKVideoCleaner_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk

# 确认这是一个 App 工程
APPLICATION_NAME = TKMetaStripper

# 加入您所有的 .m 和 .swift 文件
TKMetaStripper_FILES = main.m TKAppViewController.m \
                       TKVisualForge/Sources/TKVisualForge/VisualForgeEngine.swift \
                       TKVisualForge/Sources/TKVisualForge/V12WorkflowManager.swift

# 链接必要的框架
TKMetaStripper_FRAMEWORKS = UIKit AVFoundation CoreVideo Metal Foundation
# 如果之前有 CFLAGS 等配置，保留您的配置
TKMetaStripper_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/application.mk

# ==========================================
# 🌟 APP 专属：Metal 编译与打包管线
# ==========================================
internal-stage::
	@echo "🔥 正在锻造 GPU 视觉重构核武器 (APP 版)..."
	@xcrun -sdk iphoneos metal -c TKVisualForge/Sources/TKVisualForge/CoreShaders.metal -o $(THEOS_OBJ_DIR)/CoreShaders.air
	@xcrun -sdk iphoneos metallib $(THEOS_OBJ_DIR)/CoreShaders.air -o $(THEOS_OBJ_DIR)/default.metallib
	# ⚠️ 注意这里！App 的沙盒路径和 Tweak 完全不同！必须拷贝到 App 的 .app 文件夹里！
	@cp $(THEOS_OBJ_DIR)/default.metallib $(THEOS_STAGING_DIR)/Applications/TKMetaStripper.app/default.metallib
