#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface TKAppViewController : UIViewController <PHPickerViewControllerDelegate>

@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;

// 批量处理队列状态
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
    self.statusLabel.text = @"V6 批量引擎就绪\n(支持多选，解决闪退)\n处理完成后将统一执行一次销毁确认";
    [self.view addSubview:self.statusLabel];
    
    self.selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.selectButton.frame = CGRectMake(50, 280, self.view.bounds.size.width - 100, 55);
    [self.selectButton setTitle:@"批量选择视频并执行洗白" forState:UIControlStateNormal];
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

- (void)selectVideoTapped {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.filter = [PHPickerFilter videosFilter];
    config.selectionLimit = 0; // 🔥 0代表无限多选
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) return;
    
    // 初始化批量队列
    self.pendingResults = results;
    self.currentIndex = 0;
    self.successfullyCleanedURLs = [NSMutableArray array];
    self.assetsToDelete = [NSMutableArray array];
    
    self.selectButton.enabled = NO;
    [self.spinner startAnimating];
    
    [self processNextVideoInQueue];
}

// 递归处理队列
- (void)processNextVideoInQueue {
    if (self.currentIndex >= self.pendingResults.count) {
        // 所有视频已洗白，进入统一存删阶段
        [self commitBatchChanges];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = [NSString stringWithFormat:@"正在洗白第 %ld / %ld 个视频...\n(HEVC 重编码极度消耗性能，请勿切换App)", (long)(self.currentIndex + 1), (long)self.pendingResults.count];
    });
    
    PHPickerResult *result = self.pendingResults[self.currentIndex];
    NSString *assetIdentifier = result.assetIdentifier;
    
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
    PHAsset *originalAsset = fetchResult.firstObject;
    
    [result.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (!url) {
            // 提取失败，跳过处理下一个
            [self nextTick];
            return;
        }
        
        // 🔥 核心崩溃修复：将临时文件强行拷贝到我们的安全沙盒，切断系统自动回收机制！
        NSString *safeTempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Safe_%@.%@", [[NSUUID UUID] UUIDString], url.pathExtension]];
        NSURL *safeURL = [NSURL fileURLWithPath:safeTempPath];
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
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHEVC1920x1080];
        if (!exportSession) {
            exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1920x1080];
        }
        
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        exportSession.metadata = @[];
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            // 用完就删掉我们的安全拷贝，节省空间
            [[NSFileManager defaultManager] removeItemAtURL:safeURL error:nil];
            
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                // 成功后，加入发货清单（不立刻存盘，防止多次弹窗打扰）
                [self.successfullyCleanedURLs addObject:outputURL];
                if (originalAsset) [self.assetsToDelete addObject:originalAsset];
            }
            [self nextTick];
        }];
    });
}

// 步进器
- (void)nextTick {
    self.currentIndex++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self processNextVideoInQueue];
    });
}

// 统一落库与销毁引擎（解决多次弹窗痛点）
- (void)commitBatchChanges {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"全部压制完毕！正在安全写入相册...";
    });
    
    if (self.successfullyCleanedURLs.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.selectButton.enabled = YES;
            self.statusLabel.text = @"❌ 批处理失败：未能成功洗白任何视频。";
        });
        return;
    }
    
    // 步骤一：一次性将所有新视频存入相册
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        for (NSURL *url in self.successfullyCleanedURLs) {
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        }
    } completionHandler:^(BOOL saveSuccess, NSError * _Nullable saveError) {
        if (saveSuccess && self.assetsToDelete.count > 0) {
            
            // 步骤二：新视频落袋为安后，一次性弹出一条销毁确认框！
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest deleteAssets:self.assetsToDelete];
            } completionHandler:^(BOOL deleteSuccess, NSError * _Nullable deleteError) {
                [self finalizeUIAndCleanupWithStatus:deleteSuccess ? @"✅ 批量洗白完美收工！\n新片已入库，所有原片已销毁。" : @"⚠️ 新片已批量保存！\n但您刚才拒绝了销毁，请手动删除旧原片！"];
            }];
            
        } else {
            [self finalizeUIAndCleanupWithStatus:@"❌ 写入相册失败，未造成原文件丢失。"];
        }
    }];
}

- (void)finalizeUIAndCleanupWithStatus:(NSString *)statusText {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        self.selectButton.enabled = YES;
        self.statusLabel.text = statusText;
        
        // 清理所有沙盒临时产物
        for (NSURL *url in self.successfullyCleanedURLs) {
            [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        }
    });
}

@end
