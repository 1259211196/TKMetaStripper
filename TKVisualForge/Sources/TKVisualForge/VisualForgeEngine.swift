import Foundation
import AVFoundation
import Metal
import CoreVideo

public class VisualForgeEngine {
    
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    public init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()
        self.commandQueue = self.metalDevice?.makeCommandQueue()
    }
    
    // 基础引擎结构保留，消除所有 Warning。核心洗白逻辑已完美转移至底层 Obj-C 控制器。
    public func processVideo(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: inputURL)
        
        guard asset.isReadable, let videoTrack = asset.tracks(withMediaType: .video).first else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        do {
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let readerVideoSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoSettings)
            if reader.canAdd(videoReaderOutput) { reader.add(videoReaderOutput) }
            
            let w = Int(videoTrack.naturalSize.width)
            let h = Int(videoTrack.naturalSize.height)
            let safeW = w + (w % 2)
            let safeH = h + (h % 2)
            
            // 🌟 警告已修复：直接使用确定的高码率目标值
            let targetBitrate = 25_000_000 
            
            let writerVideoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: safeW,
                AVVideoHeightKey: safeH,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: targetBitrate,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
            videoWriterInput.expectsMediaDataInRealTime = false
            if writer.canAdd(videoWriterInput) { writer.add(videoWriterInput) }
            
            if !reader.startReading() || !writer.startWriting() {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            writer.startSession(atSourceTime: .zero)
            videoWriterInput.markAsFinished()
            writer.finishWriting { DispatchQueue.main.async { completion(writer.status == .completed) } }
            
        } catch {
            DispatchQueue.main.async { completion(false) }
        }
    }
}
