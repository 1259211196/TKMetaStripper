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
        
        guard let bundle = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let library = try? device.makeLibrary(URL: bundle),
              let kernelFunction = library.makeFunction(name: "visual_forge_kernel") else {
            print("[TKMetaStripper] 🔴 致命错误：找不到 Metal 着色器函数")
            return
        }
        
        self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
        print("[TKMetaStripper] 🟢 GPU 管线已就绪。")
    }
    
    public func processVideo(inputURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: inputURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            DispatchQueue.main.async { completion(false) }
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
            
            // 🛡️ 核心修复 1：奇数分辨率防爆锁 (强转偶数)
            let w = Int(videoTrack.naturalSize.width)
            let h = Int(videoTrack.naturalSize.height)
            let safeW = w + (w % 2)
            let safeH = h + (h % 2)
            
            let writerVideoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: safeW,
                AVVideoHeightKey: safeH
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
            
            let processingQueue = DispatchQueue(label: "com.tkmetasturpper.forgeQueue")
            
            // 🛡️ 核心修复 2：强制在闭包内捕获 reader 和 writer，防止被系统 ARC 内存死刑回收！
            videoWriterInput.requestMediaDataWhenReady(on: processingQueue) { [reader, writer] in
                
                while videoWriterInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                        videoWriterInput.markAsFinished()
                        
                        // 安全处理音频通道
                        if let aOutput = audioReaderOutput, let aInput = audioWriterInput {
                            while let audioBuffer = aOutput.copyNextSampleBuffer() {
                                // 🛡️ 核心修复 3：防死锁。如果写入器卡住，直接中断跳出，不让手机卡死
                                while !aInput.isReadyForMoreMediaData {
                                    if writer.status == .failed || writer.status == .cancelled { break }
                                    usleep(10000)
                                }
                                if writer.status == .failed { break }
                                aInput.append(audioBuffer)
                            }
                            aInput.markAsFinished()
                        }
                        
                        writer.finishWriting {
                            if writer.status == .failed {
                                print("[TKMetaStripper] 🔴 底层压制失败: \(String(describing: writer.error))")
                                DispatchQueue.main.async { completion(false) }
                                return
                            }
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
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    private func renderFrameOnGPU(pixelBuffer: CVPixelBuffer, currentTime: Float) {
        guard let commandQueue = commandQueue,
              let textureCache = textureCache,
              let pipelineState = computePipelineState else { return }
        
        // 🛡️ 核心修复 4：精准获取色彩平面真实尺寸，防止边距内存溢出
        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let widthUV = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightUV = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        
        var yTextureRef: CVMetalTexture?
        var uvTextureRef: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .r8Unorm, widthY, heightY, 0, &yTextureRef)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .rg8Unorm, widthUV, heightUV, 1, &uvTextureRef)
        
        // 🛡️ 核心修复 5：坚决剔除强制解包 (!)，如果某帧损坏直接跳过，绝不闪退 App
        guard let yRef = yTextureRef, let uvRef = uvTextureRef,
              let yTexture = CVMetalTextureGetTexture(yRef),
              let uvTexture = CVMetalTextureGetTexture(uvRef) else { 
            return 
        }
        
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
        let threadGroups = MTLSize(width: (widthY + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: (heightY + threadGroupSize.height - 1) / threadGroupSize.height,
                                   depth: 1)
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
