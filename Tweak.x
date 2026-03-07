#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "TKEnvManager.h"
#import "TKVideoCleaner.h"

// 1. App 启动入口：%ctor
%ctor {
    NSLog(@"[TKMetaStripper] 核心模块加载");
    [[TKEnvManager sharedManager] fetchDynamicNetworkEnvironment];
}

// 2. 浅层阻断：相册 UI 伪装
%hook PHAsset

- (CLLocation *)location {
    TKEnvManager *env = [TKEnvManager sharedManager];
    return [[CLLocation alloc] initWithLatitude:env.currentLatitude longitude:env.currentLongitude];
}

- (NSDate *)creationDate {
    return [NSDate date]; 
}

%end

// 3. 深层阻断：底层视频沙盒替身
%hook AVURLAsset

- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    NSString *urlString = URL.absoluteString;
    
    if ([urlString containsString:@"var/mobile/Media"] || [urlString containsString:@"pluginPayload"]) {
        NSLog(@"[TKMetaStripper] 拦截到底层视频读取: %@", URL);
        NSURL *cleanURL = [[TKVideoCleaner sharedCleaner] createStrippedDecoyVideoFromURL:URL];
        
        if (cleanURL) {
            NSLog(@"[TKMetaStripper] 已替换为沙盒替身文件: %@", cleanURL);
            return %orig(cleanURL, options);
        }
    }
    return %orig(URL, options);
}

%end
