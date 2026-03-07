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
    // 默认安全底线：德国法兰克福
    self.currentLatitude = 50.1109;
    self.currentLongitude = 8.6821;
    self.currentCountryCode = @"DE";
    self.currentTimeZone = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
}

- (void)fetchDynamicNetworkEnvironment {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"http://ip-api.com/json/?fields=status,countryCode,lat,lon,timezone"];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json[@"status"] isEqualToString:@"success"]) {
                    self.currentLatitude = [json[@"lat"] doubleValue];
                    self.currentLongitude = [json[@"lon"] doubleValue];
                    self.currentCountryCode = json[@"countryCode"];
                    self.currentTimeZone = [NSTimeZone timeZoneWithName:json[@"timezone"]];
                    NSLog(@"[TKMetaStripper] 环境已更新: %@", self.currentCountryCode);
                }
            }
        }];
        [task resume];
    });
}
@end
