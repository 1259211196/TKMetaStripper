#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <sys/utsname.h>

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

@end

@implementation TKAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self performGarbageCollection];
    
    // 预设欧洲核心国家与美国洛杉矶的物理坐标及真实时区
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
    self.statusLabel.text = @"V15 终极微创侠客版\n(0画质损伤/居中微漂移/声纹重组/FastStart)\n等待指令...";
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
    [self.selectButton setTitle:@"开始无痕物理重塑洗白" forState:UIControlStateNormal];
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
            if ([file hasPrefix:@"Safe_"] || [file hasPrefix:@"TKCleaned_"]) {
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

// 获取底层真实的硬件代号 (如 iPhone14,2)
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
        
        [strongSelf executeXiakeForgeOnURL:safeURL originalAsset:originalAsset];
    }];
}

// ==========================================
// 🚀 核心战舰：AVFoundation 级无痕微创重塑
// ==========================================
- (void)executeXiakeForgeOnURL:(NSURL *)originalURL originalAsset:(PHAsset *)originalAsset {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在执行终极无痕重构 (空间/帧率/声纹) %ld / %ld ...", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:originalURL options:nil];
        AVMutableComposition *mixComposition = [AVMutableComposition composition];
        
        AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (!videoTrack || !CMTIME_IS_VALID(videoAsset.duration)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSFileManager defaultManager] removeItemAtURL:originalURL error:nil];
                strongSelf.failedCount++;
                [strongSelf nextTick];
            });
            return;
        }
        
        AVMutableCompositionTrack *compVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [compVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
        
        AVAssetTrack *audioTrack = [[videoAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        if (audioTrack) {
            AVMutableCompositionTrack *compAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [compAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
        }
        
        // ==========================================
        // 🛡️ 物理破局 1 & 2：居中隐形微缩放 + 强制非标帧率
        // ==========================================
        AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoComposition];
        videoComp.renderSize = videoTrack.naturalSize;
        
        // 强制重设帧率为 29.97 fps (NTSC)，彻底打乱原本的 GOP 关键帧与时序结构
        videoComp.frameDuration = CMTimeMake(100, 2997); 
        
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
        
        AVMutableVideoCompositionLayerInstruction *layerInst = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compVideoTrack];
        
        // 核心刀法：绝对居中的 1.015 倍缩放，确保四周均匀隐形裁切，绝不漏黑边，完美击碎 pHash
        CGFloat scale = 1.015;
        CGAffineTransform transform = videoTrack.preferredTransform;
        CGSize naturalSize = videoTrack.naturalSize;
        CGFloat dx = naturalSize.width * (1.0 - scale) / 2.0;
        CGFloat dy = naturalSize.height * (1.0 - scale) / 2.0;
        
        CGAffineTransform scaleTransform = CGAffineTransformScale(transform, scale, scale);
        CGAffineTransform centerTransform = CGAffineTransformTranslate(scaleTransform, dx, dy);
        [layerInst setTransform:centerTransform atTime:kCMTimeZero];
        
        instruction.layerInstructions = @[layerInst];
        videoComp.instructions = @[instruction];
        
        // 锁定 HDR 与色彩空间，保死画质
        if (@available(iOS 14.0, *)) {
            if ([videoTrack hasMediaCharacteristic:AVMediaCharacteristicContainsHDRVideo]) {
                videoComp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2;
                videoComp.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2;
                videoComp.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2;
            }
        }
        
        // ==========================================
        // 🛡️ 物理破局 3：音频波形重采样 (声纹洗白)
        // ==========================================
        AVMutableAudioMix *audioMix = nil;
        if (audioTrack) {
            audioMix = [AVMutableAudioMix audioMix];
            AVMutableCompositionTrack *targetAudioTrack = [mixComposition tracksWithMediaType:AVMediaTypeAudio].firstObject;
            AVMutableAudioMixInputParameters *mixParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:targetAudioTrack];
            // 全局音量下调 2% (0.98)，人耳完全无感，但底层的音频 MD5 和频谱彻底断裂
            [mixParam setVolume:0.98 atTime:kCMTimeZero];
            audioMix.inputParameters = @[mixParam];
        }
        
        NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mp4", [[NSUUID UUID] UUIDString]]];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        
        // ==========================================
        // 🛡️ 导出装甲：启用最高画质与流媒体前置 (Fast Start)
        // ==========================================
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.videoComposition = videoComp;
        if (audioMix) {
            exportSession.audioMix = audioMix;
        }
        // 强制把 moov 原子块移到文件头部，模拟真实社交流媒体文件的原生 DNA
        exportSession.shouldOptimizeForNetworkUse = YES; 
        
        // ==========================================
        // 🛡️ 物理破局 4：无懈可击的双空间真机元数据注入
        // ==========================================
        NSMutableArray *clonedMetadata = [NSMutableArray array];
        NSString *realModel = [strongSelf getRealHardwareModel];
        NSString *systemVer = [[UIDevice currentDevice] systemVersion];
        
        // 1. 机型注入 (Common + QT 双轨)
        AVMutableMetadataItem *modelCommon = [[AVMutableMetadataItem alloc] init];
        modelCommon.keySpace = AVMetadataKeySpaceCommon;
        modelCommon.key = AVMetadataCommonKeyModel;
        modelCommon.value = realModel;
        [clonedMetadata addObject:modelCommon];
        
        AVMutableMetadataItem *modelQT = [[AVMutableMetadataItem alloc] init];
        modelQT.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        modelQT.key = AVMetadataQuickTimeMetadataKeyModel;
        modelQT.value = realModel;
        [clonedMetadata addObject:modelQT];

        // 2. 品牌注入
        AVMutableMetadataItem *makeCommon = [[AVMutableMetadataItem alloc] init];
        makeCommon.keySpace = AVMetadataKeySpaceCommon;
        makeCommon.key = AVMetadataCommonKeyMake;
        makeCommon.value = @"Apple";
        [clonedMetadata addObject:makeCommon];

        // 3. 动态时间与时区推演 (倒退随机时间)
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
        
        AVMutableMetadataItem *dateCommon = [[AVMutableMetadataItem alloc] init];
        dateCommon.keySpace = AVMetadataKeySpaceCommon;
        dateCommon.key = AVMetadataCommonKeyCreationDate;
        dateCommon.value = localTimeString;
        [clonedMetadata addObject:dateCommon];
        
        AVMutableMetadataItem *dateQT = [[AVMutableMetadataItem alloc] init];
        dateQT.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        dateQT.key = AVMetadataQuickTimeMetadataKeyCreationDate;
        dateQT.value = localTimeString;
        [clonedMetadata addObject:dateQT];

        // 4. GPS 定位锚点
        AVMutableMetadataItem *locCommon = [[AVMutableMetadataItem alloc] init];
        locCommon.keySpace = AVMetadataKeySpaceCommon;
        locCommon.key = AVMetadataCommonKeyLocation;
        locCommon.value = targetGPS;
        [clonedMetadata addObject:locCommon];
        
        AVMutableMetadataItem *locQT = [[AVMutableMetadataItem alloc] init];
        locQT.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        locQT.key = AVMetadataQuickTimeMetadataKeyLocationISO6709;
        locQT.value = targetGPS;
        [clonedMetadata addObject:locQT];

        // 5. 软件环境
        AVMutableMetadataItem *swQT = [[AVMutableMetadataItem alloc] init];
        swQT.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        swQT.key = AVMetadataQuickTimeMetadataKeySoftware;
        swQT.value = [NSString stringWithFormat:@"%@", systemVer];
        [clonedMetadata addObject:swQT];
        
        // 6. 终极伪装：补齐 iPhone 镜头与光圈的物理 Exif 参数
        [clonedMetadata addObject:[strongSelf createExifItemWithKey:(id)kCGImagePropertyExifFNumber value:@(1.8)]];
        [clonedMetadata addObject:[strongSelf createExifItemWithKey:(id)kCGImagePropertyExifFocalLength value:@(4.2)]];
        [clonedMetadata addObject:[strongSelf createExifItemWithKey:(id)kCGImagePropertyExifLensModel value:[NSString stringWithFormat:@"%@ back main camera 24mm f/1.78", realModel]]];

        exportSession.metadata = clonedMetadata;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            __strong typeof(weakSelf) innerStrongSelf = weakSelf;
            if (!innerStrongSelf) return;
            
            [[NSFileManager defaultManager] removeItemAtURL:originalURL error:nil];
            
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [innerStrongSelf.successfullyCleanedURLs addObject:outputURL];
                if (originalAsset) [innerStrongSelf.assetsToDelete addObject:originalAsset];
            } else {
                NSLog(@"[TKMetaStripper] Export Failed: %@", exportSession.error);
                innerStrongSelf.failedCount++; 
            }
            [innerStrongSelf nextTick];
        }];
    });
}

// 辅助方法：快速生成底层 Exif 标签
- (AVMutableMetadataItem *)createExifItemWithKey:(NSString *)key value:(id)value {
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.keySpace = AVMetadataKeySpaceExif;
    item.key = key;
    item.value = value;
    return item;
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
