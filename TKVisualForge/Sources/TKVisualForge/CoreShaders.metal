#include <metal_stdlib>
using namespace metal;

// 🌟 极客级无痕微创着色器 (V13 Stealth Edition)
kernel void visual_forge_kernel(texture2d<half, access::read> inTextureY [[texture(0)]],
                                texture2d<half, access::read> inTextureUV [[texture(1)]],
                                texture2d<half, access::write> outTextureY [[texture(2)]],
                                texture2d<half, access::write> outTextureUV [[texture(3)]],
                                constant float &time [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {

    // 越界保护
    if (gid.x >= outTextureY.get_width() || gid.y >= outTextureY.get_height()) {
        return;
    }

    // ==========================================
    // 1. 低频重塑：中心微缩放 (放大 1.015 倍)
    // ==========================================
    float scale = 1.015;
    float2 uv_coord = float2(gid) / float2(outTextureY.get_width(), outTextureY.get_height());
    // 以中心点(0.5, 0.5)为基准进行缩放
    uv_coord = (uv_coord - 0.5) / scale + 0.5;

    uint2 sample_coordY = uint2(uv_coord * float2(inTextureY.get_width(), inTextureY.get_height()));
    uint2 sample_coordUV = uint2(uv_coord * float2(inTextureUV.get_width(), inTextureUV.get_height()));

    // 提取原画面的亮度和色度
    half4 y_val = inTextureY.read(sample_coordY);
    half4 uv_val = inTextureUV.read(sample_coordUV);

    // ==========================================
    // 2. 彩码微扰：0.5% 亮暗与饱和度偏移
    // ==========================================
    // 亮度 (Y) 提升 0.5%
    y_val.r = y_val.r * 1.005;
    // 色度 (UV) 降低 0.5% (UV通道中心点是0.5)
    uv_val.rg = (uv_val.rg - (half)0.5) * 0.995 + (half)0.5;

    // ==========================================
    // 3. 像素粉碎：物理级静态微噪点 (核心防闪烁技术)
    // ==========================================
    // 注意：这里的随机数只和坐标(gid)有关，和时间(time)无关！绝对静止！
    float noise = fract(sin(dot(float2(gid.x, gid.y), float2(12.9898, 78.233))) * 43758.5453);
    // 将噪点强度极度压缩到 ±0.005 (0.5% 强度)
    half noise_offset = (half)(noise * 0.01 - 0.005);
    y_val.r = saturate(y_val.r + noise_offset);

    // ==========================================
    // 写入新显存
    // ==========================================
    outTextureY.write(y_val, gid);

    // UV 纹理的宽高是 Y 纹理的一半，写入前需要做边界检查
    if (gid.x < outTextureUV.get_width() && gid.y < outTextureUV.get_height()) {
        outTextureUV.write(uv_val, gid);
    }
}
