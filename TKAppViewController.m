#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface TKAppViewController : UIViewController <PHPickerViewControllerDelegate>
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation TKAppViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // UI: 状态提示文字
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 120)];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"等待选择视频...\n(矩阵防封基建：物理气隙隔离版)\n洗白后将自动销毁原片";
    [self.view addSubview:self.statusLabel];
    
    // UI: 醒目的红色操作按钮
    self.selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.selectButton.frame = CGRectMake(50, 260, self.view.bounds.size.width - 100, 55);
    [self.selectButton setTitle:@"选择视频并执行无痕洗白" forState:UIControlStateNormal];
    self.selectButton.backgroundColor = [UIColor systemRedColor];
    self.selectButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectButton.layer.cornerRadius = 12;
    [self.selectButton addTarget:self action:@selector(selectVideoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectButton];
    
    // UI: 菊花加载动画
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width/2, 380);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    // 提前向系统静默请求相册最高读写权限
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {}];
}

- (void)selectVideoTapped {
    // 使用 iOS 14+ 的现代化相册组件，防止系统偷偷在后台二压视频
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    config.filter = [PHPickerFilter videosFilter];
    config.selectionLimit = 1;
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) return;
    
    PHPickerResult *result = results.firstObject;
    NSString *assetIdentifier = result.assetIdentifier;
    
    if (!assetIdentifier) {
        self.statusLabel.text = @"无法获取原视频底层物理凭证，请换一个视频重试。";
        return;
    }
    
    // 锁定相册中带定位痕迹的原始视频身份（留作一会儿销毁用）
    PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
    PHAsset *originalAsset = fetchResult.firstObject;
    
    // 提取纯净的原始数据流
    [result.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (url && originalAsset) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self processAndCleanVideo:url originalAsset:originalAsset];
            });
        }
    }];
}

- (void)processAndCleanVideo:(NSURL *)originalURL originalAsset:(PHAsset *)originalAsset {
    self.selectButton.enabled = NO;
    self.statusLabel.text = @"🚀 正在进行工业级 HEVC 硬件重编码...\n(正在重构底层指纹，请勿退出 App)";
    [self.spinner startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:originalURL options:nil];
        NSString *tempDir = NSTemporaryDirectory();
        NSString *outputPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"TKCleaned_%@.mov", [[NSUUID UUID] UUIDString]]];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }
        
        // 核心洗白：模拟最新款 iPhone 拍摄的 1080P HEVC (H.265) 格式
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHEVC1920x1080];
        if (!exportSession) {
            exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1920x1080];
        }
        
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeQuickTimeMovie; // .mov 强封装
        exportSession.metadata = @[]; // EXIF、GPS、系统印记核弹级清空
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    [self saveVideoAndRemoveOriginalSafely:outputURL originalAsset:originalAsset];
                } else {
                    [self.spinner stopAnimating];
                    self.selectButton.enabled = YES;
                    self.statusLabel.text = [NSString stringWithFormat:@"❌ 洗白失败: %@", exportSession.error.localizedDescription];
                }
            });
        }];
    });
}

// 核心防御：分离式安全落库机制，确保永不丢片
- (void)saveVideoAndRemoveOriginalSafely:(NSURL *)newVideoURL originalAsset:(PHAsset *)originalAsset {
    self.statusLabel.text = @"✅ 重编码完成！正在安全写入系统相册...";
    
    // 步骤一：绝对优先保存纯净新片
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:newVideoURL];
    } completionHandler:^(BOOL saveSuccess, NSError * _Nullable saveError) {
        if (saveSuccess) {
            // 步骤二：新片落袋为安后，再弹窗请求销毁老片
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest deleteAssets:@[originalAsset]];
            } completionHandler:^(BOOL deleteSuccess, NSError * _Nullable deleteError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.spinner stopAnimating];
                    self.selectButton.enabled = YES;
                    
                    // 打扫战场，清理临时垃圾
                    [[NSFileManager defaultManager] removeItemAtURL:newVideoURL error:nil];
                    
                    if (deleteSuccess) {
                        self.statusLabel.text = @"🎉 完美替换！\n纯净版已安全入库，带定位痕迹的原片已彻底销毁！现在可直接去 TikTok 发布。";
                    } else {
                        self.statusLabel.text = @"⚠️ 新片已保存！\n但您刚才未允许删除，系统保留了原文件。请手动前往相册删除旧原片防泄露！";
                    }
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                self.selectButton.enabled = YES;
                self.statusLabel.text = @"❌ 保存新视频到相册失败，未造成原文件丢失。请检查手机存储空间或权限。";
            });
        }
    }];
}
@end
