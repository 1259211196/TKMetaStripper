#include <metal_stdlib>
using namespace metal;

// 🌟 武器库 1：高频混沌噪点发生器 (基于时间戳与坐标的伪随机)
float randomNoise(float2 st, float time) {
    return fract(sin(dot(st, float2(12.9898, 78.233)) + time) * 43758.5453123);
}

kernel void visual_forge_kernel(
    texture2d<float, access::read> inTextureY  [[texture(0)]],
    texture2d<float, access::read> inTextureUV [[texture(1)]],
    texture2d<float, access::write> outTextureY  [[texture(2)]],
    texture2d<float, access::write> outTextureUV [[texture(3)]],
    constant float &time [[buffer(0)]], 
    uint2 gridPosition [[thread_position_in_grid]]
) {
    uint widthY = outTextureY.get_width();
    uint heightY = outTextureY.get_height();
    
    // 边界安全锁：绝对防止闪退
    if (gridPosition.x >= widthY || gridPosition.y >= heightY) {
        return;
    }
    
    // ====================================================
    // 🛡️ 第一层：时空尺度微观呼吸 (对抗 3D-CNN 空间特征)
    // ====================================================
    float2 centerY = float2(widthY * 0.5, heightY * 0.5);
    float2 currentPosY = float2(gridPosition.x, gridPosition.y);
    
    // 构造一个 1.002 ~ 1.008 的微观缩放系数，随时间极慢呼吸
    // 这种非线性的画面缩放会让 TikTok 的固定网格截取算法完全错位
    float zoomScale = 1.005 + 0.003 * sin(time * 0.5);
    
    // 以画面中心为锚点，计算缩放后的读取坐标
    float2 zoomedPos = centerY + (currentPosY - centerY) * (1.0 / zoomScale);
    
    // 叠加原有的物理扭曲 (加入随机种子，打破正弦波规律)
    float warpStrength = 1.5;
    float noiseOffset = randomNoise(currentPosY * 0.01, time) * 2.0 - 1.0; // -1.0 到 1.0 的混沌偏移
    int offsetX = int((sin(zoomedPos.y * 0.04 + time * 1.5) + noiseOffset) * warpStrength);
    int offsetY = int((cos(zoomedPos.x * 0.04 + time * 1.5) + noiseOffset) * warpStrength);
    
    // 计算最终坐标并死锁在安全边界内
    uint2 samplePosY = uint2(
        clamp(int(zoomedPos.x) + offsetX, 0, int(widthY - 1)),
        clamp(int(zoomedPos.y) + offsetY, 0, int(heightY - 1))
    );
    
    float4 pixelY = inTextureY.read(samplePosY);
    
    // ====================================================
    // 🛡️ 第二层：高频噪点与低频重塑 (对抗 pHash 与特征点匹配)
    // ====================================================
    float dist = distance(currentPosY, centerY) / distance(float2(0,0), centerY);
    
    // 1. 低频暗角 (维持原有优势)
    float vignette = 0.04 + 0.02 * sin(time * 0.8); 
    pixelY.r = pixelY.r * (1.0 - dist * dist * vignette); 
    
    // 2. 高频噪点注入 (全新武器：极低强度的胶片级颗粒)
    // 保护金属的细腻反光，但足以让 MD5 和局部特征提取失效
    float grain = (randomNoise(currentPosY, time * 2.0) - 0.5) * 0.015;
    pixelY.r = clamp(pixelY.r + grain, 0.0, 1.0);
    
    outTextureY.write(pixelY, gridPosition);
    
    // ====================================================
    // 🛡️ 第三层：非线性彩码微扰 (对抗 色彩直方图检测)
    // ====================================================
    uint widthUV = outTextureUV.get_width();
    uint heightUV = outTextureUV.get_height();
    uint2 uvPosition = uint2(gridPosition.x / 2, gridPosition.y / 2);
    
    if (uvPosition.x < widthUV && uvPosition.y < heightUV) {
        // UV 通道跟随亮度通道进行同样的微观缩放与扭曲，防止色彩边缘溢出（紫边现象）
        float2 centerUV = float2(widthUV * 0.5, heightUV * 0.5);
        float2 currentPosUV = float2(uvPosition.x, uvPosition.y);
        float2 zoomedPosUV = centerUV + (currentPosUV - centerUV) * (1.0 / zoomScale);
        
        uint2 samplePosUV = uint2(
            clamp(int(zoomedPosUV.x) + offsetX/2, 0, int(widthUV - 1)),
            clamp(int(zoomedPosUV.y) + offsetY/2, 0, int(heightUV - 1))
        );
        
        float4 pixelUV = inTextureUV.read(samplePosUV);
        
        // 采用非线性相移：U 和 V 的变化不再是同步的正弦波，而是相互交错的混沌波
        float colorShiftStrength = 0.012; 
        float shiftU = sin(time * 1.2 + currentPosUV.x * 0.01) * colorShiftStrength;
        float shiftV = cos(time * 1.6 + currentPosUV.y * 0.01) * colorShiftStrength;
        
        pixelUV.r = clamp(pixelUV.r + shiftU, 0.0, 1.0); // U 通道
        pixelUV.g = clamp(pixelUV.g + shiftV, 0.0, 1.0); // V 通道
        
        outTextureUV.write(pixelUV, uvPosition);
    }
}
