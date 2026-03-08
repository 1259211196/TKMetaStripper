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

// 🔥 优化2：沙盒清道夫，静默清理历史遗留的替身视频，防止文稿数据无限膨胀 🔥
- (void)cleanOldDecoyVideosInBackground {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tempDir = NSTemporaryDirectory();
        NSArray *files = [fm contentsOfDirectoryAtPath:tempDir error:nil];
        NSDate *now = [NSDate date];
        
        for (NSString *file in files) {
            if ([file hasPrefix:@"TKCleaned_"]) {
                NSString *filePath = [tempDir stringByAppendingPathComponent:file];
                NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
                NSDate *creationDate = [attrs fileCreationDate];
                
                // 如果文件创建时间超过 1 小时 (3600秒)，则安全删除
                if (creationDate && [now timeIntervalSinceDate:creationDate] > 3600) {
                    [fm removeItemAtPath:filePath error:nil];
                    NSLog(@"[TKMetaStripper] 成功清理过期缓存视频: %@", file);
                }
            }
        }
    });
}

- (NSURL *)createStrippedDecoyVideoFromURL:(NSURL *)originalURL {
    // 每次执行洗白前，触发一次后台静默清理
    [self cleanOldDecoyVideosInBackground];

    if ([originalURL.path containsString:@"NSTemporaryDirectory"] || [originalURL.path containsString:@"TKCleaned"]) {
        return originalURL;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:originalURL options:nil];
    if (!asset) return originalURL;

    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mp4", uuid]];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    
    // 暴力清空所有元数据
    exportSession.metadata = @[]; 

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSLog(@"[TKMetaStripper] 开始光速清洗视频元数据...");
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
    // 超时时间缩短为 10 秒，防止遇到超大异常文件时导致 UI 假死
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(semaphore, timeout);

    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
        return outputURL;
    }
    
    return nil; 
}
@end
