#!/bin/bash

# ====================================================
# TKMetaStripper 全自动编译与 IPA 注入脚本
# 适用环境：macOS (已安装 Theos)
# 适用目标：TrollStore (巨魔) 免越狱环境
# ====================================================

# 设置颜色输出，方便查看进度
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[1/4] 清理历史编译缓存...${NC}"
make clean

echo -e "${YELLOW}[2/4] 开始编译正式版 (Release) dylib...${NC}"
# 使用 FINALPACKAGE=1 编译正式版，剥离调试符号 (Debug Symbols)。
# 这一步极其重要！带有调试符号的 dylib 文件很大，且极易被大厂风控识别为外挂！
make FINALPACKAGE=1

# 定义编译产物的默认路径 (Theos 正式版产物通常在 obj 目录下)
COMPILED_DYLIB=".theos/obj/TKMetaStripper.dylib"
OUTPUT_DYLIB="TKMetaStripper_Release.dylib"

echo -e "${YELLOW}[3/4] 验证并提取核心插件...${NC}"
if [ -f "$COMPILED_DYLIB" ]; then
    # 将隐藏目录下的 dylib 复制到项目根目录，并重命名
    cp "$COMPILED_DYLIB" "./$OUTPUT_DYLIB"
    echo -e "${GREEN}[√] 编译成功！插件已提取: ${OUTPUT_DYLIB}${NC}"
else
    echo -e "${RED}[x] 编译失败！请检查上方终端输出的报错信息。${NC}"
    exit 1
fi

echo -e "${YELLOW}[4/4] 自动化 IPA 注入准备...${NC}"
# ====================================================
# 进阶选项：自动注入 IPA (需要事先安装 Azule 工具)
# ====================================================
# 如果你想实现“一键产出可直接安装的破解版 IPA”，请取消下方代码的注释，
# 并将 SOURCE_IPA 替换为你的原版 TikTok.ipa 路径。

# SOURCE_IPA="/Users/YourName/Desktop/TikTok_Original.ipa"
# OUTPUT_DIR="/Users/YourName/Desktop/TikTok_Injected/"
# FINAL_IPA_NAME="TikTok_TKMeta_TrollStore"

# if command -v azule &> /dev/null; then
#     echo -e "${YELLOW}[*] 检测到 Azule 注入工具，开始全自动打包 IPA...${NC}"
#     azule -i "$SOURCE_IPA" -o "$OUTPUT_DIR" -f "./$OUTPUT_DYLIB" -n "$FINAL_IPA_NAME"
#     echo -e "${GREEN}[√] 终极 IPA 打包完成！请将产物发往手机通过巨魔安装。${NC}"
# else
#     echo -e "${YELLOW}[!] 未检测到 Azule。如需一键打包 IPA，请先在 Mac 上安装 Azule。${NC}"
#     echo -e "${YELLOW}[*] 目前你可以通过 Airdrop 将生成的 ${OUTPUT_DYLIB} 发送到手机，并使用 TrollFools 工具直接注入。${NC}"
# fi

echo -e "${GREEN}=================== 全部任务执行完毕 ===================${NC}"
