#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <sys/utsname.h> // 🔥 引入底层 C 语言库，用于获取主板真实硬件代号

@interface TKAppViewController : UIViewController <PHPickerViewControllerDelegate>

@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) NSArray<PHPickerResult *> *pendingResults;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSMutableArray<NSURL *> *successfullyCleanedURLs;
@property (nonatomic, strong) NSMutableArray<PHAsset *> *assetsToDelete;

@end

@implementation TKAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 150)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"V7 上帝伪造版就绪\n(100% 真实主板指纹克隆)\n完美伪装原生拍摄，对抗终极查重";
    [self.view addSubview:self.statusLabel];
    
    self.selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.selectButton.frame = CGRectMake(50, 280, self.view.bounds.size.width - 100, 55);
    [self.selectButton setTitle:@"执行 100% 真机克隆洗白" forState:UIControlStateNormal];
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

// 🔥 核心底层方法：获取当前设备的真实主板硬件代号 (如 iPhone14,2)
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
    self.successfullyCleanedURLs = [NSMutableArray array];
    self.assetsToDelete = [NSMutableArray array];
    
    self.selectButton.enabled = NO;
    [self.spinner startAnimating];
    [self processNextVideoInQueue];
}

- (void)processNextVideoInQueue {
    if (self.currentIndex >= self.pendingResults.count) {
        [self commitBatchChanges];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在克隆第 %ld / %ld 个视频...\n(注入真实硬件级指纹，请勿退出)", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });
    
    PHPickerResult *result = self.pendingResults[self.currentIndex];
    NSString *assetIdentifier = result.assetIdentifier;
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
    PHAsset *originalAsset = fetchResult.firstObject;
    
    [result.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (!url) {
            [self nextTick];
            return;
        }
        
        NSString *safeTempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Safe_%@.%@", [[NSUUID UUID] UUIDString], url.pathExtension]];
        NSURL *safeURL = [NSURL fileURLWithPath:safeTempPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:safeTempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:safeTempPath error:nil];
        }
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:safeURL error:nil];
        
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
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1280x720];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie; 
        
        // ==========================================
        // 🔥 V7 终极克隆：100% 真实设备原生数据结构
        // ==========================================
        NSMutableArray *clonedMetadata = [NSMutableArray array];
        
        // 1. 制造商 (Apple)
        AVMutableMetadataItem *makeItem = [[AVMutableMetadataItem alloc] init];
        makeItem.keySpace = AVMetadataKeySpaceCommon;
        makeItem.key = AVMetadataCommonKeyMake;
        makeItem.value = @"Apple";
        [clonedMetadata addObject:makeItem];
        
        // 2. 真实物理主板型号 (例如：iPhone15,3)
        AVMutableMetadataItem *modelItem = [[AVMutableMetadataItem alloc] init];
        modelItem.keySpace = AVMetadataKeySpaceCommon;
        modelItem.key = AVMetadataCommonKeyModel;
        modelItem.value = [self getRealHardwareModel];
        [clonedMetadata addObject:modelItem];
        
        // 3. 真实系统软件版本 (例如：17.4.1)
        AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
        softwareItem.keySpace = AVMetadataKeySpaceCommon;
        softwareItem.key = AVMetadataCommonKeySoftware;
        softwareItem.value = [[UIDevice currentDevice] systemVersion];
        [clonedMetadata addObject:softwareItem];
        
        // 4. 精确到微秒的真实生成时间
        AVMutableMetadataItem *dateItem = [[AVMutableMetadataItem alloc] init];
        dateItem.keySpace = AVMetadataKeySpaceCommon;
        dateItem.key = AVMetadataCommonKeyCreationDate;
        dateItem.value = [NSDate date];
        [clonedMetadata addObject:dateItem];
        
        // 5. 真实 GPS 定位注入 (采用苹果严格的 ISO-6709 标准)
        // ⚠️ 极度重要警告：这里我为你预设了【德国法兰克福】的真实经纬度坐标。
        // 因为你在做欧洲 TikTok，如果注入你真实的中国物理 GPS，账号会瞬间死掉！
        // 这里的坐标为法兰克福：北纬 50.1109，东经 8.6821
        AVMutableMetadataItem *locationItem = [[AVMutableMetadataItem alloc] init];
        locationItem.keySpace = AVMetadataKeySpaceCommon;
        locationItem.key = AVMetadataCommonKeyLocation;
        locationItem.value = @"+50.1109+008.6821/"; 
        [clonedMetadata addObject:locationItem];
        
        // 将克隆数据写入视频内脏
        exportSession.metadata = clonedMetadata;
        // ==========================================
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            [[NSFileManager defaultManager] removeItemAtURL:safeURL error:nil];
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [self.successfullyCleanedURLs addObject:outputURL];
                if (originalAsset) [self.assetsToDelete addObject:originalAsset];
            } else {
                NSLog(@"[TKVideoCleaner] 洗白失败: %@", exportSession.error.localizedDescription);
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
        self.statusLabel.text = @"全部克隆完毕！正在安全写入相册...";
    });
    if (self.successfullyCleanedURLs.count == 0) {
        [self finalizeUIAndCleanupWithStatus:@"❌ 批处理失败：未能成功洗白任何视频。"];
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
                [self finalizeUIAndCleanupWithStatus:deleteSuccess ? @"✅ 100% 真机克隆完美收工！\n新片已入库，所有原片已彻底销毁。" : @"⚠️ 新片已批量保存！\n但您刚才拒绝了销毁，请手动删除旧原片防止泄漏！"];
            }];
        } else {
            [self finalizeUIAndCleanupWithStatus:@"❌ 写入相册失败，未造成原文件丢失。请检查相册权限。"];
        }
    }];
}

- (void)finalizeUIAndCleanupWithStatus:(NSString *)statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.selectButton.enabled = YES;
        self.statusLabel.text = statusText;
        for (NSURL *url in self.successfullyCleanedURLs) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
    });
}

@end
