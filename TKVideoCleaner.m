#import "TKVideoCleaner.h"
#import <AVFoundation/AVFoundation.h>

@implementation TKVideoCleaner

+ (instancetype)sharedCleaner {
    static TKVideoCleaner *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSURL *)createStrippedDecoyVideoFromURL:(NSURL *)originalURL {
    // 1. 防止死循环：如果已经是我们临时目录里的替身文件，直接放行
    if ([originalURL.path containsString:@"NSTemporaryDirectory"] || [originalURL.path containsString:@"TKCleaned"]) {
        return originalURL;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:originalURL options:nil];
    if (!asset) return originalURL;

    // 2. 生成沙盒临时路径 (每次生成一个唯一的文件名)
    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mp4", uuid]];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // 如果之前存在同名文件，先删掉（虽然 UUID 几乎不可能重复，但保持好习惯）
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }

    // 3. 配置导出 Session (Passthrough 模式速度极快，不重新编码画面，只重写容器)
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    
    // 🔥 核心洗白操作：强制清空所有元数据 (GPS、拍摄时间、相机型号等) 🔥
    exportSession.metadata = @[]; 

    // 4. 同步阻塞导出 (利用信号量)
    // 注意：因为 TikTok 调用 initWithURL: 是期待立刻拿到实例的，所以我们需要用信号量把异步的导出过程变成同步。
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSLog(@"[TKMetaStripper] 开始清洗视频元数据...");
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            NSLog(@"[TKMetaStripper] 视频清洗完成，已生成安全替身: %@", outputPath);
        } else {
            NSLog(@"[TKMetaStripper] 洗白失败: %@", exportSession.error);
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    // 等待导出完成，设置一个超时时间 (例如 15 秒)，防止 App 卡死
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(semaphore, timeout);

    // 5. 返回安全的替身路径
    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
        return outputURL;
    }
    
    // 如果超时或失败，为了安全起见，这里可以设计为返回 nil，阻断上传，而不是返回包含危险信息的原文件
    return nil; 
}

@end
