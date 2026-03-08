#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "TKEnvManager.h"
#import "TKVideoCleaner.h"

%ctor {
    NSLog(@"[TKMetaStripper] 核心模块加载 (V2 优化版)");
    [[TKEnvManager sharedManager] fetchDynamicNetworkEnvironment];
}

%hook PHAsset

- (CLLocation *)location {
    TKEnvManager *env = [TKEnvManager sharedManager];
    return [[CLLocation alloc] initWithLatitude:env.currentLatitude longitude:env.currentLongitude];
}

- (NSDate *)creationDate {
    return [NSDate date]; 
}

%end


%hook AVURLAsset

- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    NSString *urlString = URL.absoluteString.lowercaseString; // 转小写方便匹配
    
    // 🔥 优化3：增加后缀名严格校验。只有确定是视频格式，才进行耗时的沙盒拦截 🔥
    BOOL isVideoFormat = [urlString hasSuffix:@".mp4"] || [urlString hasSuffix:@".mov"] || [urlString hasSuffix:@".m4v"];
    BOOL isTargetDirectory = [urlString containsString:@"var/mobile/media"] || [urlString containsString:@"pluginpayload"];
    
    if (isTargetDirectory && isVideoFormat) {
        NSLog(@"[TKMetaStripper] 命中底层视频文件，准备拦截: %@", URL);
        
        // 注意：此处仍有轻微的同步耗时（几十到几百毫秒），
        // 这是为了彻底防住 TikTok C++ 引擎强扫底层物理文件所必须付出的“安全代价”。
        NSURL *cleanURL = [[TKVideoCleaner sharedCleaner] createStrippedDecoyVideoFromURL:URL];
        
        if (cleanURL) {
            NSLog(@"[TKMetaStripper] 已成功替换为沙盒纯净替身: %@", cleanURL);
            return %orig(cleanURL, options);
        }
    }
    
    // 如果是图片、音频或系统缓存，直接光速放行，绝对不卡顿主线程
    return %orig(URL, options);
}

%end
