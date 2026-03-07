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

// 1. 读取本地缓存 (防瞬移与无网容灾)
- (void)loadCachedEnvironment {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cachedCountry = [defaults stringForKey:@"TK_CountryCode"];

    if (cachedCountry && cachedCountry.length > 0) {
        // 读取上次成功验证的物理节点
        self.currentLatitude = [defaults doubleForKey:@"TK_Lat"];
        self.currentLongitude = [defaults doubleForKey:@"TK_Lon"];
        self.currentCountryCode = cachedCountry;
        
        NSString *tzName = [defaults stringForKey:@"TK_TimeZone"];
        self.currentTimeZone = tzName ? [NSTimeZone timeZoneWithName:tzName] : [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        
        NSLog(@"[TKMetaStripper] 已加载本地缓存节点: %@", self.currentCountryCode);
    } else {
        // 首次安装的默认底线：德国法兰克福 (Latitude: 50.1109, Longitude: 8.6821)
        self.currentLatitude = 50.1109;
        self.currentLongitude = 8.6821;
        self.currentCountryCode = @"DE";
        self.currentTimeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        
        NSLog(@"[TKMetaStripper] 无缓存，已加载默认底线: 法兰克福");
    }
}

// 2. 异步验证网络并静默更新缓存
- (void)fetchDynamicNetworkEnvironment {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 请求极简的 Geo-IP 接口
        NSURL *url = [NSURL URLWithString:@"http://ip-api.com/json/?fields=status,countryCode,lat,lon,timezone"];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json[@"status"] isEqualToString:@"success"]) {
                    
                    // 动态更新内存数据
                    self.currentLatitude = [json[@"lat"] doubleValue];
                    self.currentLongitude = [json[@"lon"] doubleValue];
                    self.currentCountryCode = json[@"countryCode"];
                    self.currentTimeZone = [NSTimeZone timeZoneWithName:json[@"timezone"]];
                    
                    NSLog(@"[TKMetaStripper] 节点环境已确认: %@", self.currentCountryCode);
                    
                    // 将最新确认的节点存入沙盒，供下次 App 启动时瞬间读取
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
