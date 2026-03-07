#import <Foundation/Foundation.h>

@interface TKEnvManager : NSObject

@property (nonatomic, assign) double currentLatitude;
@property (nonatomic, assign) double currentLongitude;
@property (nonatomic, copy) NSString *currentCountryCode;
@property (nonatomic, strong) NSTimeZone *currentTimeZone;

+ (instancetype)sharedManager;
- (void)fetchDynamicNetworkEnvironment;

@end
