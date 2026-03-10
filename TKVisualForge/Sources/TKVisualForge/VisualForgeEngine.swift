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
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        self.metalDevice = device
        self.commandQueue = device.makeCommandQueue()
        
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        self.textureCache = cache
        
        guard let bundle = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let library = try? device.makeLibrary(URL: bundle),
              let kernelFunction = library.makeFunction(name: "visual_forge_kernel") else { return }
        
        self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
    }
    
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
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoSettings)
            videoReaderOutput.alwaysCopiesSampleData = false
            if reader.canAdd(videoReaderOutput) { reader.add(videoReaderOutput) }
            
            let w = Int(videoTrack.naturalSize.width)
            let h = Int(videoTrack.naturalSize.height)
            let safeW = w + (w % 2)
            let safeH = h + (h % 2)
            let estimatedBitrate = videoTrack.estimatedDataRate > 0 ? videoTrack.estimatedDataRate : 25000000
            
            let writerVideoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: safeW,
                AVVideoHeightKey: safeH,
                AVVideoCompressionPropertiesKey: [ AVVideoAverageBitRateKey: Int(estimatedBitrate) ]
            ]
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
            videoWriterInput.expectsMediaDataInRealTime = false
            videoWriterInput.transform = videoTrack.preferredTransform
            if writer.canAdd(videoWriterInput) { writer.add(videoWriterInput) }
            
            // 🌟 终极适配器：强制写入宽高和 IOSurface，保障系统绝对能分出内存！
            let sourceBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                kCVPixelBufferWidthKey as String: safeW,
                kCVPixelBufferHeightKey as String: safeH
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
            
            if !reader.startReading() {
                DispatchQueue.main.async { completion(false) }
                return
            }
            if !writer.startWriting() {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let processingQueue = DispatchQueue(label: "com.tkmetasturpper.forgeQueue")
            var isSessionStarted = false
            
            videoWriterInput.requestMediaDataWhenReady(on: processingQueue) { [weak self] in
                guard let self = self else { return }
                
                while videoWriterInput.isReadyForMoreMediaData {
                    if reader.status != .reading {
                        videoWriterInput.markAsFinished()
                        if isSessionStarted {
                            writer.finishWriting { DispatchQueue.main.async { completion(writer.status == .completed) } }
                        } else {
                            writer.cancelWriting()
                            DispatchQueue.main.async { completion(false) }
                        }
                        break
                    }
                    
                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        
                        if !isSessionStarted {
                            writer.startSession(atSourceTime: pts)
                            isSessionStarted = true
                        }
                        
                        var frameAppended = false
                        
                        autoreleasepool {
                            if let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                let width = CVPixelBufferGetWidth(sourceBuffer)
                                let height = CVPixelBufferGetHeight(sourceBuffer)
                                
                                // 🌟 独立强开内存区：拒绝看系统脸色，直接手写内存条！
                                var destBuffer: CVPixelBuffer?
                                let attrs = [
                                    kCVPixelBufferMetalCompatibilityKey: true,
                                    kCVPixelBufferIOSurfacePropertiesKey: [:]
                                ] as CFDictionary
                                
                                let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, attrs, &destBuffer)
                                
                                if status == kCVReturnSuccess, let dBuffer = destBuffer {
                                    let time = pts.isValid ? Float(pts.seconds) : 0.0
                                    self.renderFrameOnGPU(source: sourceBuffer, dest: dBuffer, currentTime: time)
                                    
                                    if writer.status == .writing {
                                        frameAppended = adaptor.append(dBuffer, withPresentationTime: pts)
                                    }
                                }
                            }
                        }
                        
                        // 🌟 终极防爆兜底：如果 GPU 出任何意外（极低概率），把原版画面硬塞进去！确保管线不断裂！
                        if !frameAppended && writer.status == .writing {
                            videoWriterInput.append(sampleBuffer)
                        }
                        
                    } else {
                        videoWriterInput.markAsFinished()
                        if isSessionStarted {
                            writer.finishWriting { DispatchQueue.main.async { completion(writer.status == .completed) } }
                        } else {
                            writer.cancelWriting()
                            DispatchQueue.main.async { completion(false) }
                        }
                        break
                    }
                }
            }
        } catch {
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    private func renderFrameOnGPU(source: CVPixelBuffer, dest: CVPixelBuffer, currentTime: Float) {
        guard let commandQueue = commandQueue,
              let textureCache = textureCache,
              let pipelineState = computePipelineState else { return }
        
        let widthY = CVPixelBufferGetWidthOfPlane(source, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(source, 0)
        let widthUV = CVPixelBufferGetWidthOfPlane(source, 1)
        let heightUV = CVPixelBufferGetHeightOfPlane(source, 1)
        
        guard widthY > 0 && heightY > 0 && widthUV > 0 && heightUV > 0 else { return }
        
        var srcYRef: CVMetalTexture?
        var srcUVRef: CVMetalTexture?
        var dstYRef: CVMetalTexture?
        var dstUVRef: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, source, nil, .r8Unorm, widthY, heightY, 0, &srcYRef)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, source, nil, .rg8Unorm, widthUV, heightUV, 1, &srcUVRef)
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, dest, nil, .r8Unorm, widthY, heightY, 0, &dstYRef)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, dest, nil, .rg8Unorm, widthUV, heightUV, 1, &dstUVRef)
        
        guard let sY = srcYRef, let sUV = srcUVRef, let dY = dstYRef, let dUV = dstUVRef,
              let texSY = CVMetalTextureGetTexture(sY),
              let texSUV = CVMetalTextureGetTexture(sUV),
              let texDY = CVMetalTextureGetTexture(dY),
              let texDUV = CVMetalTextureGetTexture(dUV) else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texSY, index: 0)
        encoder.setTexture(texSUV, index: 1)
        encoder.setTexture(texDY, index: 2)
        encoder.setTexture(texDUV, index: 3)
        
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
