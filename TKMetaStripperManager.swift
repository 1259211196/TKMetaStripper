import Foundation

@objc public class TKMetaStripperManager: NSObject {
    
    private let visualForge = VisualForgeEngine()
    
    @objc public override init() {
        super.init()
    }
    
    // 专门为 Objective-C 准备的桥接方法，带有完成回调
    @objc public func forgeVideo(
        inputPath: String, 
        outputPath: String, 
        completion: @escaping (Bool) -> Void
    ) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        try? FileManager.default.removeItem(at: outputURL)
        
        print("🚀 [GPU Forge] 启动底层视觉重构...")
        visualForge.processVideo(inputURL: inputURL, outputURL: outputURL) { success in
            completion(success)
        }
    }
}
