import Foundation
import AVFoundation
import Metal
import CoreVideo

public class VisualForgeEngine {
    
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    private var computePipelineState: MTLComputePipelineState?
    
    public init() {
        setupMetalEnvironment()
    }
    
    private func setupMetalEnvironment() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[TKMetaStripper] 🔴 致命错误：设备不支持 Metal")
            return
        }
        self.metalDevice = device
        self.commandQueue = device.makeCommandQueue()
        
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        self.textureCache = cache
        
        // 🔧 修复点 1：使用 Bundle.main，因为我们现在是独立的 App！
        guard let bundle = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let library = try? device.makeLibrary(URL: bundle),
              let kernelFunction = library.makeFunction(name: "visual_forge_kernel") else {
            print("[TKMetaStripper] 🔴 致命错误：找不到 Metal 着色器函数")
            return
        }
        
        self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
        print("[TKMetaStripper] 🟢 视觉锻造炉点火成功！GPU 管线已就绪。")
    }
    
    public func processVideo(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        print("[TKMetaStripper] 🚀 开始深度洗白全流程: \(inputURL.lastPathComponent)")
        
        let asset = AVAsset(url: inputURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("[TKMetaStripper] 🔴 错误：找不到视频轨道")
            completion(false)
            return
        }
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        do {
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let readerVideoSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoSettings)
            videoReaderOutput.alwaysCopiesSampleData = false
            reader.add(videoReaderOutput)
            
            let writerVideoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: videoTrack.naturalSize.width,
                AVVideoHeightKey: videoTrack.naturalSize.height
            ]
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
            videoWriterInput.expectsMediaDataInRealTime = false
            videoWriterInput.transform = videoTrack.preferredTransform
            writer.add(videoWriterInput)
            
            var audioReaderOutput: AVAssetReaderTrackOutput?
            var audioWriterInput: AVAssetWriterInput?
            if let aTrack = audioTrack {
                audioReaderOutput = AVAssetReaderTrackOutput(track: aTrack, outputSettings: nil)
                reader.add(audioReaderOutput!)
                
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                audioWriterInput!.expectsMediaDataInRealTime = false
                writer.add(audioWriterInput!)
            }
            
            reader.startReading()
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            
            let processingQueue = DispatchQueue(label: "com.tkmetasturpper.visualForgeQueue")
            
            videoWriterInput.requestMediaDataWhenReady(on: processingQueue) {
                while videoWriterInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                        videoWriterInput.markAsFinished()
                        
                        if let aOutput = audioReaderOutput, let aInput = audioWriterInput {
                            while let audioBuffer = aOutput.copyNextSampleBuffer() {
                                if aInput.isReadyForMoreMediaData {
                                    aInput.append(audioBuffer)
                                }
                            }
                            aInput.markAsFinished()
                        }
                        
                        writer.finishWriting {
                            print("[TKMetaStripper] 🟢 洗白完成！已生成纯净原生视频。")
                            DispatchQueue.main.async { completion(true) }
                        }
                        break
                    }
                    
                    autoreleasepool {
                        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                        let time = Float(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
                        self.renderFrameOnGPU(pixelBuffer: pixelBuffer, currentTime: time)
                        videoWriterInput.append(sampleBuffer)
                    }
                }
            }
        } catch {
            print("[TKMetaStripper] 🔴 管线崩溃: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func renderFrameOnGPU(pixelBuffer: CVPixelBuffer, currentTime: Float) {
        // 🔧 修复点 2：去掉了未使用的 device 变量，消除了警告
        guard let commandQueue = commandQueue,
              let textureCache = textureCache,
              let pipelineState = computePipelineState else { return }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var yTextureRef: CVMetalTexture?
        var uvTextureRef: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .r8Unorm, width, height, 0, &yTextureRef)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .rg8Unorm, width / 2, height / 2, 1, &uvTextureRef)
        
        guard let yTexture = CVMetalTextureGetTexture(yTextureRef!),
              let uvTexture = CVMetalTextureGetTexture(uvTextureRef!) else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipelineState)
        
        encoder.setTexture(yTexture, index: 0)
        encoder.setTexture(uvTexture, index: 1)
        encoder.setTexture(yTexture, index: 2)
        encoder.setTexture(uvTexture, index: 3)
        
        var timeValue = currentTime
        encoder.setBytes(&timeValue, length: MemoryLayout<Float>.size, index: 0)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
                                   depth: 1)
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
} // 🔧 修复点 3：补齐了丢失的类结束大括号！
