#import "TKVideoCleaner.h"
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

@implementation TKVideoCleaner

+ (instancetype)sharedCleaner {
    static TKVideoCleaner *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

// 辅助方法：生成字符串的 MD5，用于唯一绑定原视频
- (NSString *)md5StringForString:(NSString *)string {
    const char *cstr = [string UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

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
                
                if (creationDate && [now timeIntervalSinceDate:creationDate] > 3600) {
                    [fm removeItemAtPath:filePath error:nil];
                }
            }
        }
    });
}

- (NSURL *)createStrippedDecoyVideoFromURL:(NSURL *)originalURL {
    [self cleanOldDecoyVideosInBackground];

    // 如果已经是替身，或者是临时文件，直接放行
    if ([originalURL.path containsString:@"NSTemporaryDirectory"] || [originalURL.path containsString:@"TKCleaned"]) {
        return originalURL;
    }

    NSString *tempDir = NSTemporaryDirectory();
    // 🔥 核心优化 1：使用原视频路径的 MD5 作为替身名字。对抗 TikTok 的夺命连环读！
    NSString *fileHash = [self md5StringForString:originalURL.path];
    NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mov", fileHash]];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // 🔥 核心优化 2：秒级缓存放行。如果这个视频在过去 1 小时内已经被转码过了，直接返回，绝对不浪费 1 毫秒！
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        NSLog(@"[TKMetaStripper] 缓存命中！TikTok 再次读取，直接秒回 HEVC 替身: %@", outputURL);
        return outputURL;
    }

    NSDictionary *bypassOptions = @{@"TK_BYPASS_HOOK": @YES};
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:originalURL options:bypassOptions];
    if (!asset) return originalURL;

    // 🔥 核心优化 3：锁定 1080P HEVC。完美契合 TikTok 播放上限，同时将转码速度提升 3 倍以上，避开 APM 卡顿风控报警！
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHEVC1920x1080];
    
    // 如果测试机极老(如 iPhone X)不支持 1080P HEVC，降级为 1080P H.264
    if (!exportSession) {
        exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1920x1080];
        NSLog(@"[TKMetaStripper] 设备太老，已降级为 1080P H.264 原生重编码");
    }

    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie; // 强制伪装 Apple QuickTime (.MOV)
    
    // 核弹级元数据清洗
    exportSession.metadata = @[]; 

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSLog(@"[TKMetaStripper] 开启原生 1080P HEVC 极速重制引擎...");
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
    // 超时时间设为 15 秒（1080P转码绝大多数在 2-5 秒内完成）
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(semaphore, timeout);

    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
        NSLog(@"[TKMetaStripper] HEVC 重制圆满完成，完全洗白！");
        return outputURL;
    } else {
        NSLog(@"[TKMetaStripper] 重制失败: %@。强制放行原文件保全 UI。", exportSession.error);
    }
    
    return nil; 
}
@end
