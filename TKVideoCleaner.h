#import <Foundation/Foundation.h>

@interface TKVideoCleaner : NSObject

+ (instancetype)sharedCleaner;
- (NSURL *)createStrippedDecoyVideoFromURL:(NSURL *)originalURL;

@end
