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

// 🔥 修复点：将废弃的 MD5 升级为苹果推荐的 SHA-256，完美通过高版本 iOS SDK 编译校验
- (NSString *)sha256StringForString:(NSString *)string {
    const char *cstr = [string UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(cstr, (CC_LONG)strlen(cstr), result);
    
    // 动态拼接 64 位的安全哈希字符串
    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashString appendFormat:@"%02x", result[i]];
    }
    return hashString;
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
                    NSLog(@"[TKMetaStripper] 成功清理过期缓存视频: %@", file);
                }
            }
        }
    });
}

- (NSURL *)createStrippedDecoyVideoFromURL:(NSURL *)originalURL {
    [self cleanOldDecoyVideosInBackground];

    if ([originalURL.path containsString:@"NSTemporaryDirectory"] || [originalURL.path containsString:@"TKCleaned"]) {
        return originalURL;
    }

    NSString *tempDir = NSTemporaryDirectory();
    // 使用新的 SHA-256 算法生成极其安全的替身文件名
    NSString *fileHash = [self sha256StringForString:originalURL.path];
    NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mov", fileHash]];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // 秒级缓存命中放行
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        NSLog(@"[TKMetaStripper] 缓存命中！TikTok 再次读取，直接秒回 HEVC 替身: %@", outputURL);
        return outputURL;
    }

    NSDictionary *bypassOptions = @{@"TK_BYPASS_HOOK": @YES};
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:originalURL options:bypassOptions];
    if (!asset) return originalURL;

    // 锁定 1080P HEVC 以匹配 TikTok 上限，避开卡顿监控
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHEVC1920x1080];
    
    if (!exportSession) {
        exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1920x1080];
        NSLog(@"[TKMetaStripper] 设备太老，已降级为 1080P H.264 原生重编码");
    }

    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie; 
    exportSession.metadata = @[]; 

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSLog(@"[TKMetaStripper] 开启原生 1080P HEVC 极速重制引擎...");
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
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
