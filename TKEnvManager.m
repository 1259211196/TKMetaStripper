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

// 1. 读取本地缓存
- (void)loadCachedEnvironment {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cachedCountry = [defaults stringForKey:@"TK_CountryCode"];

    if (cachedCountry && cachedCountry.length > 0) {
        // 如果有上次成功的缓存，就用缓存（比如上次是法国，刚打开App时也是法国，防止位置瞬移）
        self.currentLatitude = [defaults doubleForKey:@"TK_Lat"];
        self.currentLongitude = [defaults doubleForKey:@"TK_Lon"];
        self.currentCountryCode = cachedCountry;
        
        NSString *tzName = [defaults stringForKey:@"TK_TimeZone"];
        self.currentTimeZone = tzName ? [NSTimeZone timeZoneWithName:tzName] : [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        
        NSLog(@"[TKMetaStripper] 加载本地缓存节点: %@", cachedCountry);
    } else {
        // 只有真正的“第一次安装使用”，或者缓存丢失时，才使用法兰克福作为绝对的安全底线
        self.currentLatitude = 50.1109;
        self.currentLongitude = 8.6821;
        self.currentCountryCode = @"DE";
        self.currentTimeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        
        NSLog(@"[TKMetaStripper] 无缓存，加载默认安全底线: 法兰克福");
    }
}

// 2. 异步请求最新网络环境，并更新缓存
- (void)fetchDynamicNetworkEnvironment {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"http://ip-api.com/json/?fields=status,countryCode,lat,lon,timezone"];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json[@"status"] isEqualToString:@"success"]) {
                    
                    // 获取最新的 VPN 节点数据
                    self.currentLatitude = [json[@"lat"] doubleValue];
                    self.currentLongitude = [json[@"lon"] doubleValue];
                    self.currentCountryCode = json[@"countryCode"];
                    self.currentTimeZone = [NSTimeZone timeZoneWithName:json[@"timezone"]];
                    
                    NSLog(@"[TKMetaStripper] 网络环境已确认/更新: %@", self.currentCountryCode);
                    
                    // 🔥 核心新增：将这次成功的节点数据存入本地缓存，留给下次启动时使用 🔥
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setDouble:self.currentLatitude forKey:@"TK_Lat"];
                    [defaults setDouble:self.currentLongitude forKey:@"TK_Lon"];
                    [defaults setObject:self.currentCountryCode forKey:@"TK_CountryCode"];
                    [defaults setObject:json[@"timezone"] forKey:@"TK_TimeZone"];
                    [defaults synchronize];
                }
            }
        }];
        [task resume];
    });
}
@end
