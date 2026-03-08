#import "TKEnvManager.h"

@implementation TKEnvManager

+ (instancetype)sharedManager {
    static TKEnvManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared loadCachedEnvironment];
    });
    return shared;
}

- (void)loadCachedEnvironment {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cachedCountry = [defaults stringForKey:@"TK_CountryCode"];

    if (cachedCountry && cachedCountry.length > 0) {
        self.currentLatitude = [defaults doubleForKey:@"TK_Lat"];
        self.currentLongitude = [defaults doubleForKey:@"TK_Lon"];
        self.currentCountryCode = cachedCountry;
        
        NSString *tzName = [defaults stringForKey:@"TK_TimeZone"];
        self.currentTimeZone = tzName ? [NSTimeZone timeZoneWithName:tzName] : [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        NSLog(@"[TKMetaStripper] 已加载本地缓存节点: %@", self.currentCountryCode);
    } else {
        // 首次安装的默认底线：德国法兰克福
        self.currentLatitude = 50.1109;
        self.currentLongitude = 8.6821;
        self.currentCountryCode = @"DE";
        self.currentTimeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        NSLog(@"[TKMetaStripper] 无缓存，已加载默认底线: 法兰克福");
    }
}

- (void)fetchDynamicNetworkEnvironment {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 🔥 优化1：使用支持 HTTPS 的商业级开源接口，完美绕过 iOS ATS 拦截 🔥
        NSURL *url = [NSURL URLWithString:@"https://freeipapi.com/api/json"];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json && json[@"countryCode"]) {
                    
                    self.currentLatitude = [json[@"latitude"] doubleValue];
                    self.currentLongitude = [json[@"longitude"] doubleValue];
                    self.currentCountryCode = json[@"countryCode"];
                    self.currentTimeZone = [NSTimeZone timeZoneWithName:json[@"timeZone"]];
                    
                    NSLog(@"[TKMetaStripper] HTTPS 节点验证成功: %@", self.currentCountryCode);
                    
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setDouble:self.currentLatitude forKey:@"TK_Lat"];
                    [defaults setDouble:self.currentLongitude forKey:@"TK_Lon"];
                    [defaults setObject:self.currentCountryCode forKey:@"TK_CountryCode"];
                    [defaults setObject:json[@"timeZone"] forKey:@"TK_TimeZone"];
                    [defaults synchronize];
                }
            } else {
                NSLog(@"[TKMetaStripper] HTTPS 节点请求失败: %@", error.localizedDescription);
            }
        }];
        [task resume];
    });
}
@end
