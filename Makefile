# 1. 基础编译环境 (保持与您截图一致)
TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = TKMetaStripper

# 🌟 核心：common.mk 绝对只能出现一次
include $(THEOS)/makefiles/common.mk

# 2. 定义项目名称
APPLICATION_NAME = TKMetaStripper

# 3. 源代码文件列表 (路径必须与 GitHub 物理路径完全一致)
TKMetaStripper_FILES = main.m TKAppViewController.m \
                       TKVisualForge/Sources/TKVisualForge/VisualForgeEngine.swift \
                       TKMetaStripperManager.swift

# 4. 框架配置
TKMetaStripper_FRAMEWORKS = UIKit AVFoundation Photos MobileCoreServices PhotosUI CoreVideo Metal Foundation

# 5. Swift 5.0 支持
TKMetaStripper_SWIFT_VERSION = 5
TKMetaStripper_CFLAGS = -fobjc-arc

# 核心打包逻辑
include $(THEOS)/makefiles/application.mk

# ==========================================
# 🌟 GPU 渲染引擎编译与注入 (适配 TKMetaStripper 路径)
# ==========================================
internal-stage::
	@echo "🔥 正在为 TKMetaStripper 锻造 GPU 核武器..."
	@xcrun -sdk iphoneos metal -c TKVisualForge/Sources/TKVisualForge/CoreShaders.metal -o $(THEOS_OBJ_DIR)/CoreShaders.air
	@xcrun -sdk iphoneos metallib $(THEOS_OBJ_DIR)/CoreShaders.air -o $(THEOS_OBJ_DIR)/default.metallib
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/TKMetaStripper.app/
	@cp $(THEOS_OBJ_DIR)/default.metallib $(THEOS_STAGING_DIR)/Applications/TKMetaStripper.app/default.metallib
