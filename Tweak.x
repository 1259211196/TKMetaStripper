#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "TKEnvManager.h"
#import "TKVideoCleaner.h"

%ctor {
    NSLog(@"[TKMetaStripper] 核心模块加载 (终极防闪退版)");
    [[TKEnvManager sharedManager] fetchDynamicNetworkEnvironment];
}

// 1. 浅层阻断：相册 UI 伪装
%hook PHAsset

- (CLLocation *)location {
    TKEnvManager *env = [TKEnvManager sharedManager];
    return [[CLLocation alloc] initWithLatitude:env.currentLatitude longitude:env.currentLongitude];
}

- (NSDate *)creationDate {
    return [NSDate date]; 
}

%end

// 2. 深层阻断：底层视频沙盒替身
%hook AVURLAsset

- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    
    // 🔥 核心防御：识别免死金牌，打破无限循环导致的闪退
    if (options && [options[@"TK_BYPASS_HOOK"] boolValue]) {
        NSMutableDictionary *mutOptions = [NSMutableDictionary dictionaryWithDictionary:options];
        [mutOptions removeObjectForKey:@"TK_BYPASS_HOOK"];
        return %orig(URL, mutOptions.count > 0 ? mutOptions : nil);
    }

    NSString *urlString = URL.absoluteString.lowercaseString;
    
    // 严格校验格式，防止拖慢图片和系统音频的加载速度
    BOOL isVideoFormat = [urlString hasSuffix:@".mp4"] || [urlString hasSuffix:@".mov"] || [urlString hasSuffix:@".m4v"];
    BOOL isTargetDirectory = [urlString containsString:@"var/mobile/media"] || [urlString containsString:@"pluginpayload"];
    
    if (isTargetDirectory && isVideoFormat) {
        NSLog(@"[TKMetaStripper] 命中底层视频文件，准备拦截: %@", URL);
        
        NSURL *cleanURL = [[TKVideoCleaner sharedCleaner] createStrippedDecoyVideoFromURL:URL];
        
        if (cleanURL) {
            NSLog(@"[TKMetaStripper] 已成功替换为沙盒纯净替身: %@", cleanURL);
            return %orig(cleanURL, options);
        }
    }
    
    return %orig(URL, options);
}

%end
