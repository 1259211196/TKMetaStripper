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
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        do {
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            // --- 🎬 视频通道准备 ---
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
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: Int(estimatedBitrate)
                ]
            ]
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
            videoWriterInput.expectsMediaDataInRealTime = false
            videoWriterInput.transform = videoTrack.preferredTransform
            if writer.canAdd(videoWriterInput) { writer.add(videoWriterInput) }
            
            // --- 🎵 音频通道准备 ---
            var audioReaderOutput: AVAssetReaderTrackOutput?
            var audioWriterInput: AVAssetWriterInput?
            
            if let aTrack = audioTrack {
                let aOutput = AVAssetReaderTrackOutput(track: aTrack, outputSettings: nil)
                if reader.canAdd(aOutput) { reader.add(aOutput) }
                audioReaderOutput = aOutput
                
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 128000
                ]
                let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                aInput.expectsMediaDataInRealTime = false
                if writer.canAdd(aInput) { writer.add(aInput) }
                audioWriterInput = aInput
            }
            
            reader.startReading()
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            
            // 🚀 核心大修：单线程“拉链式”交织写入，彻底解决闪退与死锁！
            let processingQueue = DispatchQueue(label: "com.tkmetasturpper.forgeQueue")
            
            processingQueue.async { [weak self] in
                guard let self = self else { return }
                
                var videoDone = false
                var audioDone = (audioTrack == nil)
                
                // 只要视频或音频有一个没写完，就继续循环
                while !videoDone || !audioDone {
                    
                    if reader.status == .failed || writer.status == .failed || writer.status == .cancelled {
                        break
                    }
                    
                    var wroteDataThisCycle = false
                    
                    // 1. 尝试写一帧视频
                    if !videoDone && videoWriterInput.isReadyForMoreMediaData {
                        if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                            autoreleasepool {
                                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                                    let time = Float(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
                                    self.renderFrameOnGPU(pixelBuffer: pixelBuffer, currentTime: time)
                                }
                                videoWriterInput.append(sampleBuffer)
                            }
                            wroteDataThisCycle = true
                        } else {
                            videoWriterInput.markAsFinished()
                            videoDone = true
                        }
                    }
                    
                    // 2. 尝试写一帧音频
                    if !audioDone, let aInput = audioWriterInput, let aOutput = audioReaderOutput {
                        if aInput.isReadyForMoreMediaData {
                            if let sampleBuffer = aOutput.copyNextSampleBuffer() {
                                aInput.append(sampleBuffer)
                                wroteDataThisCycle = true
                            } else {
                                aInput.markAsFinished()
                                audioDone = true
                            }
                        }
                    }
                    
                    // 3. 如果底层缓冲区满了（这轮既没写视频也没写音频），休眠 5 毫秒防 CPU 卡死
                    if !wroteDataThisCycle && (!videoDone || !audioDone) {
                        usleep(5000)
                    }
                }
                
                // 🏁 全部写完，安全收尾
                if writer.status == .failed {
                    print("[TKMetaStripper] 底层封装失败: \(String(describing: writer.error))")
                    DispatchQueue.main.async { completion(false) }
                } else {
                    writer.finishWriting {
                        DispatchQueue.main.async {
                            completion(writer.status == .completed)
                        }
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
        
        let widthY = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let heightY = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let widthUV = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let heightUV = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        
        var yTextureRef: CVMetalTexture?
        var uvTextureRef: CVMetalTexture?
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .r8Unorm, widthY, heightY, 0, &yTextureRef)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .rg8Unorm, widthUV, heightUV, 1, &uvTextureRef)
        
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
