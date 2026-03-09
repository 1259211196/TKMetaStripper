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

// 🎯 V12 终极升级：自带时区特征的多国物理坐标库
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
    
    // 启动级底层垃圾回收，防止磁盘爆满
    [self performGarbageCollection];
    
    // 🔥 终极数据结构：绑定国家的物理坐标与标准时区，彻底消除零时区破绽
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
    self.statusLabel.text = @"V12 上帝级完备版就绪\n(最高画质锁死 / GPS随机误差 / 本地时区)\n已达到 100% 物理真实伪装";
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
            if ([file hasPrefix:@"Safe_"] || [file hasPrefix:@"TKCleaned_"]) {
                [fm removeItemAtPath:[tempDir stringByAppendingPathComponent:file] error:nil];
            }
        }
        NSLog(@"[TKVideoCleaner] 启动级磁盘清道夫已完毕。");
    });
}

- (void)showCountryPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🌍 切换矩阵目标国家"
                                                                   message:@"新生成的视频将烙印该国家的绝对物理GPS坐标与时区"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (int i = 0; i < self.countryData.count; i++) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:self.countryData[i][@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"TKTargetCountryIndex"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.countryButton setTitle:[NSString stringWithFormat:@"🎯 当前目标区: %@", self.countryData[i][@"name"]] forState:UIControlStateNormal];
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.countryButton;
        alert.popoverPresentationController.sourceRect = self.countryButton.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getRealHardwareModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在进行上帝级重构 %ld / %ld ...\n(锁死最高画质，请耐心等待)", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });
    
    PHPickerResult *result = self.pendingResults[self.currentIndex];
    NSString *assetIdentifier = result.assetIdentifier;
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
    PHAsset *originalAsset = fetchResult.firstObject;
    
    [result.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        
        if (!url || error) {
            NSLog(@"[TKVideoCleaner] 视频源流提取失败: %@", error);
            self.failedCount++;
            [self nextTick];
            return;
        }
        
        NSString *safeTempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Safe_%@.%@", [[NSUUID UUID] UUIDString], url.pathExtension]];
        NSURL *safeURL = [NSURL fileURLWithPath:safeTempPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:safeTempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:safeTempPath error:nil];
        }
        
        NSError *copyError = nil;
        BOOL copySuccess = [[NSFileManager defaultManager] copyItemAtURL:url toURL:safeURL error:&copyError];
        if (!copySuccess) {
            self.failedCount++;
            [self nextTick];
            return;
        }
        
        [self executeCleanOnSafeURL:safeURL originalAsset:originalAsset];
    }];
}

- (void)executeCleanOnSafeURL:(NSURL *)safeURL originalAsset:(PHAsset *)originalAsset {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:safeURL options:nil];
        NSString *tempDir = NSTemporaryDirectory();
        NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mov", [[NSUUID UUID] UUIDString]]];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        
        // 🎯 优化 1：强制解除 720P 封印，动态继承源文件的极限分辨率与最高质量
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        
        // 🎯 色彩重构系统：检测 HDR 并强制映射到 BT.709 防灰
        AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (@available(iOS 16.0, *)) {
            if ([videoTrack hasMediaCharacteristic:AVMediaCharacteristicFormatDescriptionPeersWithHDRContext]) {
                AVMutableVideoComposition *videoComp = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
                if (videoComp) {
                    videoComp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2;
                    videoComp.colorTransferFunction = AVVideoColorTransferFunction_ITU_R_709_2;
                    videoComp.colorYCbCrMatrix = AVVideoColorYCbCrMatrix_ITU_R_709_2;
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
        modelItem.value = [self getRealHardwareModel];
        [clonedMetadata addObject:modelItem];
        
        AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
        softwareItem.keySpace = AVMetadataKeySpaceCommon;
        softwareItem.key = AVMetadataCommonKeySoftware;
        softwareItem.value = [[UIDevice currentDevice] systemVersion];
        [clonedMetadata addObject:softwareItem];
        
        // 提取用户配置的国家、GPS、时区
        NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TKTargetCountryIndex"];
        if (savedIndex >= self.countryData.count) savedIndex = 0;
        NSString *targetGPS = self.countryData[savedIndex][@"gps"];
        NSString *targetTZ = self.countryData[savedIndex][@"tz"];
        
        // 🎯 优化 2：根据选择的国家，强行注入当地时区偏移量（消除零时区 Z 的脚本特征）
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:targetTZ]];
        NSString *localTimeString = [formatter stringFromDate:[NSDate date]];
        
        AVMutableMetadataItem *dateItem = [[AVMutableMetadataItem alloc] init];
        dateItem.keySpace = AVMetadataKeySpaceCommon;
        dateItem.key = AVMetadataCommonKeyCreationDate;
        dateItem.value = localTimeString;
        [clonedMetadata addObject:dateItem];
        
        // 写入 GPS 坐标
        AVMutableMetadataItem *locationItem = [[AVMutableMetadataItem alloc] init];
        locationItem.keySpace = AVMetadataKeySpaceCommon;
        locationItem.key = AVMetadataCommonKeyLocation;
        locationItem.value = targetGPS; 
        [clonedMetadata addObject:locationItem];
        
        // 🎯 优化 3：随机注入卫星搜星误差精度 (15米 - 65米)，达成 100% 硬件乱真
        AVMutableMetadataItem *accuracyItem = [[AVMutableMetadataItem alloc] init];
        accuracyItem.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
        accuracyItem.key = AVMetadataQuickTimeMetadataKeyLocationAccuracyHorizontal;
        int randomAccuracy = 15 + arc4random_uniform(51); 
        accuracyItem.value = @(randomAccuracy);
        [clonedMetadata addObject:accuracyItem];
        
        exportSession.metadata = clonedMetadata;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            [[NSFileManager defaultManager] removeItemAtURL:safeURL error:nil];
            
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [self.successfullyCleanedURLs addObject:outputURL];
                if (originalAsset) [self.assetsToDelete addObject:originalAsset];
            } else {
                NSLog(@"[TKVideoCleaner] 底层重编码失败: %@", exportSession.error.localizedDescription);
                self.failedCount++; 
            }
            [self nextTick];
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
        self.statusLabel.text = @"全部底层重写完毕！正在安全入库...";
    });
    
    if (self.successfullyCleanedURLs.count == 0) {
        [self finalizeUIAndCleanupWithStatus:[NSString stringWithFormat:@"❌ 批处理全军覆没。\n%ld 个视频全部洗白失败。", (long)self.failedCount]];
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
                NSString *finalStatus = [NSString stringWithFormat:@"%@\n成功: %ld 个 | 失败: %ld 个", 
                                         deleteSuccess ? @"✅ 矩阵入库完美收工！旧片已销毁。" : @"⚠️ 新片已保存！但您拒绝了自动销毁旧片。",
                                         (long)self.successfullyCleanedURLs.count,
                                         (long)self.failedCount];
                [self finalizeUIAndCleanupWithStatus:finalStatus];
            }];
        } else {
            [self finalizeUIAndCleanupWithStatus:@"❌ 写入相册被系统拦截，请检查权限设置。"];
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
