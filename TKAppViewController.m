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
    
    // 启动级底层垃圾回收，防止磁盘爆满
    [self performGarbageCollection];
    
    self.countryData = @[
        @{@"name": @"🇩🇪 德国 (法兰克福)", @"gps": @"+50.1109+008.6821/"},
        @{@"name": @"🇫🇷 法国 (巴黎)",     @"gps": @"+48.8566+002.3522/"},
        @{@"name": @"🇪🇸 西班牙 (马德里)", @"gps": @"+40.4168-003.7038/"},
        @{@"name": @"🇮🇹 意大利 (罗马)",   @"gps": @"+41.9028+012.4964/"},
        @{@"name": @"🇬🇧 英国 (伦敦)",     @"gps": @"+51.5074-000.1278/"},
        @{@"name": @"🇺🇸 美国 (洛杉矶)",   @"gps": @"+34.0522-118.2437/"}
    ];
    
    NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TKTargetCountryIndex"];
    if (savedIndex >= self.countryData.count) savedIndex = 0; 
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 120)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"V10 满血原生版就绪\n(1080P HEVC 原生编码 + 多国定位)\n完美对标真实 iPhone 极致画质";
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
                                                                   message:@"新生成的视频将烙印该国家的绝对物理GPS坐标"
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
        self.statusLabel.text = [NSString stringWithFormat:@"正在克隆第 %ld / %ld 个视频...\n(满血 1080P HEVC 压制中，请耐心)", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
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
            NSLog(@"[TKVideoCleaner] 拷贝到沙盒失败: %@", copyError);
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
        
        // 🔥 核心重装：切回 1080P HEVC (H.265)，还原最强物理真实度
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHEVC1920x1080];
        
        // 极少部分异常原片如果不支持直接升维至 HEVC，增加一个底层保底的 H.264 1080P，防止崩溃
        if (!exportSession) {
            exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1920x1080];
        }
        
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie; 
        
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
        
        AVMutableMetadataItem *dateItem = [[AVMutableMetadataItem alloc] init];
        dateItem.keySpace = AVMetadataKeySpaceCommon;
        dateItem.key = AVMetadataCommonKeyCreationDate;
        dateItem.value = [NSDate date];
        [clonedMetadata addObject:dateItem];
        
        NSInteger savedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"TKTargetCountryIndex"];
        if (savedIndex >= self.countryData.count) savedIndex = 0;
        NSString *targetGPS = self.countryData[savedIndex][@"gps"];
        
        AVMutableMetadataItem *locationItem = [[AVMutableMetadataItem alloc] init];
        locationItem.keySpace = AVMetadataKeySpaceCommon;
        locationItem.key = AVMetadataCommonKeyLocation;
        locationItem.value = targetGPS; 
        [clonedMetadata addObject:locationItem];
        
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
        self.statusLabel.text = @"全部压制完毕！正在执行安全入库事务...";
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
                                         deleteSuccess ? @"✅ 入库完美收工！旧片已销毁。" : @"⚠️ 新片已保存！但您拒绝了自动销毁旧片。",
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
