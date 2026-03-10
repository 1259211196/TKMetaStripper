import Foundation
import UIKit
import struct utsname

@objc public class TKMetaStripperManager: NSObject {
    
    // 引用深层文件夹里的渲染引擎
    private let visualForge = VisualForgeEngine()
    
    @objc public override init() {
        super.init()
    }
    
    private func getRealDeviceMachineString() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iPhone14,5" : identifier
    }
    
    @objc public func startUltimateProcess(
        videoPath: String,
        locationName: String,
        lat: Double,
        lon: Double
    ) {
        let inputURL = URL(fileURLWithPath: videoPath)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("TK_Processed.mp4")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        print("🚀 [TKMetaStripper] 启动！设备: \(getRealDeviceMachineString()) | 目标: \(locationName)")
        
        visualForge.processVideo(inputURL: inputURL, outputURL: outputURL) { success in
            if success {
                print("✅ [GPU] 重构成功: \(outputURL.path)")
                // 接下来可以继续执行您的元数据剥离逻辑...
            }
        }
    }
}
