# 1. 基础编译环境配置
TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TKVideoCleaner

# 🌟 核心：common.mk 只准出现这一次！
include $(THEOS)/makefiles/common.mk

# 2. 定义 App 名称 (确保全局统一)
APPLICATION_NAME = TKVideoCleaner

# 3. 合并所有源代码文件 (ObjC + Swift)
TKVideoCleaner_FILES = main.m TKAppViewController.m \
                       TKVisualForge/Sources/TKVisualForge/VisualForgeEngine.swift \
                       TKVisualForge/Sources/TKVisualForge/V12WorkflowManager.swift

# 4. 合并所有必要的框架 (加入 Metal 和 CoreVideo 用于视频渲染)
TKVideoCleaner_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI CoreVideo Metal Foundation

# 5. 开启 Swift 5.0 支持与 ARC 内存管理
TKVideoCleaner_SWIFT_VERSION = 5.0
TKVideoCleaner_CFLAGS = -fobjc-arc

# 🌟 核心：application.mk 负责最后的链接打包
include $(THEOS)/makefiles/application.mk

# ==========================================
# 🌟 APP 专属：Metal 编译与打包管线
# ==========================================
internal-stage::
	@echo "🔥 正在锻造 GPU 视觉重构核武器 (APP 版)..."
	# 编译着色器为二进制 air 文件
	@xcrun -sdk iphoneos metal -c TKVisualForge/Sources/TKVisualForge/CoreShaders.metal -o $(THEOS_OBJ_DIR)/CoreShaders.air
	# 链接为苹果设备可读取的 metallib
	@xcrun -sdk iphoneos metallib $(THEOS_OBJ_DIR)/CoreShaders.air -o $(THEOS_OBJ_DIR)/default.metallib
	# ⚠️ 关键：将编译好的库拷贝到 App 的安装目录中
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/TKVideoCleaner.app/
	@cp $(THEOS_OBJ_DIR)/default.metallib $(THEOS_STAGING_DIR)/Applications/TKVideoCleaner.app/default.metallib
