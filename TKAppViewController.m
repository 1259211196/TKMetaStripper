#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <sys/utsname.h>

#import "TKMetaStripper-Swift.h"

@interface TKAppViewController : UIViewController <PHPickerViewControllerDelegate>

@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSArray *countryData;
@property (nonatomic, strong) NSArray<PHPickerResult *> *pendingResults;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableArray<NSURL *> *successfullyCleanedURLs;
@property (nonatomic, strong) NSMutableArray<PHAsset *> *assetsToDelete;
@property (nonatomic, assign) NSInteger failedCount;
@property (nonatomic, strong) TKMetaStripperManager *forgeManager;

@end

@implementation TKAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self performGarbageCollection];
    
    self.countryData = @[
        @{@"name": @"🇩🇪 德国 (法兰克福)", @"gps": @"+50.1109+008.6821/", @"tz": @"Europe/Berlin"},
        @{@"name": @"🇫🇷 法国 (巴黎)",     @"gps": @"+48.8566+002.3522/", @"tz": @"Europe/Paris"},
        @{@"name": @"🇪🇸 西班牙 (马德里)", @"gps": @"+40.4168-003.7038/", @"tz": @"Europe/Madrid"},
        @{@"name": @"🇮🇹 意大利 (罗马)",   @"gps": @"+41.9028+012.4964/", @"tz": @"Europe/Rome"},
        @{@"name": @"🇬🇧 英国 (伦敦)",     @"gps": @"+51.5074-000.1278/", @"tz": @"Europe/London"},
        @{@"name": @"🇺🇸 美国 (洛杉矶)",   @"gps": @"+34.0522-118.2437/", @"tz": @"America/Los_Angeles"}
    ];
    
    NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TKTargetCountryIndex"];
    if (savedIndex >= self.countryData.count) savedIndex = 0; 
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 120)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"V12 绝对防线终极版就绪\n(内存池已隔离，免疫一切秒退)\n等待下发指令...";
    [self.view addSubview:self.statusLabel];
    
    self.countryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.countryButton.frame = CGRectMake(50, 220, self.view.bounds.size.width - 100, 45);
    [self.countryButton setTitle:[NSString stringWithFormat:@"🎯 当前目标区: %@", self.countryData[savedIndex][@"name"]] forState:UIControlStateNormal];
    self.countryButton.backgroundColor = [UIColor systemGray6Color];
    [self.countryButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.countryButton.layer.cornerRadius = 10;
    self.countryButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.countryButton addTarget:self action:@selector(showCountryPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.countryButton];
    
    self.selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.selectButton.frame = CGRectMake(50, 285, self.view.bounds.size.width - 100, 55);
    [self.selectButton setTitle:@"开始 100% 真机克隆洗白" forState:UIControlStateNormal];
    self.selectButton.backgroundColor = [UIColor systemRedColor];
    self.selectButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectButton.layer.cornerRadius = 12;
    [self.selectButton addTarget:self action:@selector(selectVideoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width/2, 400);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {}];
}

- (void)performGarbageCollection {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *tempDir = NSTemporaryDirectory();
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *files = [fm contentsOfDirectoryAtPath:tempDir error:nil];
        for (NSString *file in files) {
            if ([file hasPrefix:@"Safe_"] || [file hasPrefix:@"TKCleaned_"] || [file hasPrefix:@"Forged_"]) {
                [fm removeItemAtPath:[tempDir stringByAppendingPathComponent:file] error:nil];
            }
        }
    });
}

- (void)showCountryPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🌍 切换矩阵目标国家" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (int i = 0; i < self.countryData.count; i++) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:self.countryData[i][@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"TKTargetCountryIndex"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.countryButton setTitle:[NSString stringWithFormat:@"🎯 当前目标区: %@", self.countryData[i][@"name"]] forState:UIControlStateNormal];
        }];
        [alert addAction:action];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.countryButton;
        alert.popoverPresentationController.sourceRect = self.countryButton.bounds;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getRealHardwareModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] ?: @"iPhone";
}

- (void)selectVideoTapped {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.filter = [PHPickerFilter videosFilter];
    config.selectionLimit = 0; 
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    
    self.pendingResults = results;
    self.currentIndex = 0;
    self.failedCount = 0; 
    self.successfullyCleanedURLs = [NSMutableArray array];
    self.assetsToDelete = [NSMutableArray array];
    
    self.selectButton.enabled = NO;
    self.countryButton.enabled = NO; 
    [self.spinner startAnimating];
    [self processNextVideoInQueue];
}

- (void)processNextVideoInQueue {
    if (self.currentIndex >= self.pendingResults.count) {
        [self commitBatchChanges];
        return;
    }
    
    PHPickerResult *result = self.pendingResults[self.currentIndex];
    NSString *assetIdentifier = result.assetIdentifier;
    
    PHAsset *originalAsset = nil;
    if (assetIdentifier != nil) {
        PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
        originalAsset = fetchResult.firstObject;
    }
    
    NSString *typeIdentifier = @"public.movie";
    if (![result.itemProvider hasItemConformingToTypeIdentifier:typeIdentifier]) {
        typeIdentifier = result.itemProvider.registeredTypeIdentifiers.firstObject ?: @"public.movie";
    }
    
    __weak typeof(self) weakSelf = self;
    [result.itemProvider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (!url || error) {
            strongSelf.failedCount++;
            [strongSelf nextTick];
            return;
        }
        
        NSString *safeTempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Safe_%@.%@", [[NSUUID UUID] UUIDString], url.pathExtension]];
        NSURL *safeURL = [NSURL fileURLWithPath:safeTempPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:safeTempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:safeTempPath error:nil];
        }
        
        NSError *copyError = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:url toURL:safeURL error:&copyError]) {
            strongSelf.failedCount++;
            [strongSelf nextTick];
            return;
        }
        
        [strongSelf executeGPUForgeOnSafeURL:safeURL originalAsset:originalAsset];
    }];
}

- (void)executeGPUForgeOnSafeURL:(NSURL *)safeURL originalAsset:(PHAsset *)originalAsset {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在进行 GPU 视觉重构 %ld / %ld ...\n(引擎全速推进中)", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });

    NSString *tempDir = NSTemporaryDirectory();
    NSString *forgedPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"Forged_%@.mp4", [[NSUUID UUID] UUIDString]]];
    
    self.forgeManager = [[TKMetaStripperManager alloc] init];
    
    __weak typeof(self) weakSelf = self;
    [self.forgeManager forgeVideoWithInputPath:safeURL.path outputPath:forgedPath completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (!success) {
            [[NSFileManager defaultManager] removeItemAtURL:safeURL error:nil];
            strongSelf.failedCount++;
            [strongSelf nextTick];
            return;
        }
        
        NSURL *forgedURL = [NSURL fileURLWithPath:forgedPath];
        [strongSelf executeCleanOnForgedURL:forgedURL originalVideoURL:safeURL originalAsset:originalAsset];
    }];
}

- (void)executeCleanOnForgedURL:(NSURL *)forgedURL originalVideoURL:(NSURL *)originalURL originalAsset:(PHAsset *)originalAsset {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在注入底层物理特征与重组音轨 %ld / %ld ...", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        AVURLAsset *forgedVideoAsset = [[AVURLAsset alloc] initWithURL:forgedURL options:nil];
        AVURLAsset *originalAudioAsset = [[AVURLAsset alloc] initWithURL:originalURL options:nil];
        
        AVMutableComposition *mixComposition = [AVMutableComposition composition];
        
        // 🌟 上帝级验证锁：绝不允许无效时长的空壳视频引发底层崩溃！
        AVAssetTrack *forgedVideoTrack = [[forgedVideoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (forgedVideoTrack && CMTIME_IS_VALID(forgedVideoAsset.duration) && forgedVideoAsset.duration.value > 0) {
            AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, forgedVideoAsset.duration) ofTrack:forgedVideoTrack atTime:kCMTimeZero error:nil];
        } else {
            // 如果 GPU 处理出现不可抗力产出空文件，立即阻断崩溃，安全走向失败计次
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSFileManager defaultManager] removeItemAtURL:forgedURL error:nil];
                [[NSFileManager defaultManager] removeItemAtURL:originalURL error:nil];
                strongSelf.failedCount++;
                [strongSelf nextTick];
            });
            return;
        }
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        AVAssetTrack *origAudioTrack = [[originalAudioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        if (origAudioTrack) {
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, forgedVideoAsset.duration) ofTrack:origAudioTrack atTime:kCMTimeZero error:nil];
        }
        
        NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mp4", [[NSUUID UUID] UUIDString]]];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        
        if (@available(iOS 14.0, *)) {
            if ([forgedVideoTrack hasMediaCharacteristic:AVMediaCharacteristicContainsHDRVideo]) {
                AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:mixComposition];
                if (videoComp) {
                    videoComp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2;
                    videoComp.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2;
                    videoComp.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2;
                    exportSession.videoComposition = videoComp;
                }
            }
        }
        
        NSMutableArray *clonedMetadata = [NSMutableArray array];
        
        AVMutableMetadataItem *makeItem = [[AVMutableMetadataItem alloc] init];
        makeItem.keySpace = AVMetadataKeySpaceCommon;
        makeItem.key = AVMetadataCommonKeyMake;
        makeItem.value = @"Apple";
        [clonedMetadata addObject:makeItem];
        
        AVMutableMetadataItem *modelItem = [[AVMutableMetadataItem alloc] init];
        modelItem.keySpace = AVMetadataKeySpaceCommon;
        modelItem.key = AVMetadataCommonKeyModel;
        modelItem.value = [strongSelf getRealHardwareModel]; 
        [clonedMetadata addObject:modelItem];
        
        AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
        softwareItem.keySpace = AVMetadataKeySpaceCommon;
        softwareItem.key = AVMetadataCommonKeySoftware;
        softwareItem.value = [[UIDevice currentDevice] systemVersion];
        [clonedMetadata addObject:softwareItem];
        
        NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TKTargetCountryIndex"];
        if (savedIndex >= strongSelf.countryData.count) savedIndex = 0;
        NSString *targetGPS = strongSelf.countryData[savedIndex][@"gps"];
        NSString *targetTZ = strongSelf.countryData[savedIndex][@"tz"];
        
        int randomSecondsDelay = (10 + arc4random_uniform(170)) * 60;
        NSDate *randomizedPastDate = [[NSDate date] dateByAddingTimeInterval:-randomSecondsDelay];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:targetTZ]];
        NSString *localTimeString = [formatter stringFromDate:randomizedPastDate];
        
        AVMutableMetadataItem *dateItem = [[AVMutableMetadataItem alloc] init];
        dateItem.keySpace = AVMetadataKeySpaceCommon;
        dateItem.key = AVMetadataCommonKeyCreationDate;
        dateItem.value = localTimeString;
        [clonedMetadata addObject:dateItem];
        
        AVMutableMetadataItem *locationItem = [[AVMutableMetadataItem alloc] init];
        locationItem.keySpace = AVMetadataKeySpaceCommon;
        locationItem.key = AVMetadataCommonKeyLocation;
        locationItem.value = targetGPS; 
        [clonedMetadata addObject:locationItem];
        
        AVMutableMetadataItem *accuracyItem = [[AVMutableMetadataItem alloc] init];
        accuracyItem.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        accuracyItem.key = @"com.apple.quicktime.location.accuracy.horizontal"; 
        accuracyItem.value = @(15 + arc4random_uniform(51));
        [clonedMetadata addObject:accuracyItem];
        
        exportSession.metadata = clonedMetadata;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            __strong typeof(weakSelf) innerStrongSelf = weakSelf;
            if (!innerStrongSelf) return;
            
            [[NSFileManager defaultManager] removeItemAtURL:forgedURL error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:originalURL error:nil];
            
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [innerStrongSelf.successfullyCleanedURLs addObject:outputURL];
                if (originalAsset) [innerStrongSelf.assetsToDelete addObject:originalAsset];
            } else {
                innerStrongSelf.failedCount++; 
            }
            [innerStrongSelf nextTick];
        }];
    });
}

- (void)nextTick {
    self.currentIndex++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self processNextVideoInQueue];
    });
}

- (void)commitBatchChanges {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"处理完毕！正在入库...";
    });
    
    if (self.successfullyCleanedURLs.count == 0) {
        [self finalizeUIAndCleanupWithStatus:[NSString stringWithFormat:@"❌ 失败: %ld 个视频。", (long)self.failedCount]];
        return;
    }
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        for (NSURL *url in self.successfullyCleanedURLs) {
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        }
    } completionHandler:^(BOOL saveSuccess, NSError * _Nullable saveError) {
        if (saveSuccess && self.assetsToDelete.count > 0) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest deleteAssets:self.assetsToDelete];
            } completionHandler:^(BOOL deleteSuccess, NSError * _Nullable deleteError) {
                [self finalizeUIAndCleanupWithStatus:[NSString stringWithFormat:@"%@\n成功: %ld | 失败: %ld", 
                                         deleteSuccess ? @"✅ 成功入库并销毁旧片！" : @"⚠️ 新片已保存！",
                                         (long)self.successfullyCleanedURLs.count, (long)self.failedCount]];
            }];
        } else {
            [self finalizeUIAndCleanupWithStatus:@"❌ 相册写入被拒绝。"];
        }
    }];
}

- (void)finalizeUIAndCleanupWithStatus:(NSString *)statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.selectButton.enabled = YES;
        self.countryButton.enabled = YES; 
        self.statusLabel.text = statusText;
        for (NSURL *url in self.successfullyCleanedURLs) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
    });
}

@end
