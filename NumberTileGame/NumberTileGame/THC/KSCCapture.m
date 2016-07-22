//
//  KSCCapture.m
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//

#import "KSCCapture.h"
//#import "CGContextCreator.h"
#import <libksygpulive/libksygpulive.h>

static NSUInteger kKSCCaptureFrameRate = 10;
static NSString *const kKSCCaptureErrorDomain = @"com.ksc.capture.error.domain";
static NSString *const kFileName = @"output.mp4";
#define kKSCCaptureSnapshotQueue "com.ksc.capture.snapshot.queue"

@interface KSCCapture()

@property(nonatomic, strong) AVAssetWriter *videoWriter;
@property(nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property(nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *avAdaptor;

// 开始时间
@property(nonatomic, strong) NSDate *startedAt;

// 按帧率写屏的定时器
@property (nonatomic, strong) NSTimer *timer;

// 截图队列
@property (nonatomic, strong) dispatch_queue_t captureQueue;

// 当前最上层window 截屏获取上下文所需
@property (nonatomic, strong) UIWindow *frontWindow;

//配置录制环境
- (void)setUpWriter;
//清理录制环境
- (void)cleanupWriter;
//完成录制工作
- (void)completeRecordingSession;
//录制每一帧
- (void)drawFrame;
@end

@implementation KSCCapture

- (UIWindow *)frontWindow
{
    if (!_frontWindow) {
        _frontWindow = [[UIApplication sharedApplication] keyWindow];
        if (_frontWindow.windowLevel != UIWindowLevelNormal)
        {
            NSArray *windows = [[UIApplication sharedApplication] windows];
            for(UIWindow * tmpWin in windows)
            {
                if (tmpWin.windowLevel == UIWindowLevelNormal)
                {
                    _frontWindow = tmpWin;
                    break;
                }
            }
        }
    }
    return _frontWindow;
}

+ (instancetype)defaultRecorder
{
    return [[self alloc] initWithFrameRate:kKSCCaptureFrameRate];
}

- (instancetype)init
{
    return [self initWithFrameRate:kKSCCaptureFrameRate];
}

- (instancetype)initWithFrameRate:(NSUInteger)frameRate
{
    NSParameterAssert(frameRate > 0);
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.captureQueue = dispatch_queue_create(kKSCCaptureSnapshotQueue, DISPATCH_QUEUE_SERIAL);
    
    return self;
}

- (void)dealloc {
	[self cleanupWriter];
}

#pragma mark -
#pragma mark CustomMethod

- (void)startRecording
{
    if (self.videoWriter.status == AVAssetWriterStatusWriting) {
        return;
    }
    
    // 配置录制环境
    [self setUpWriter];

    self.startedAt = [NSDate date];
    //绘屏的定时器
    self.timer = [[NSTimer alloc] initWithFireDate:self.startedAt interval:1.0/_frameRate target:self selector:@selector(drawFrame) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];

}

- (void)stopRecording
{
    [self.timer invalidate];
    [self completeRecordingSession];
}

- (void)drawFrame
{
    __weak KSCCapture *weakSelf = self;
    dispatch_async(weakSelf.captureQueue, ^{
        [weakSelf captureScreen];
    });
    
//    if (!_isShotting) {
//        [self performSelectorInBackground:@selector(captureScreen) withObject:nil];
//    }
}

- (void)captureScreen
{
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.frontWindow.layer renderInContext:context];
    self.frontWindow.layer.contents = nil;
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    NSTimeInterval millisElapsed = [[NSDate date] timeIntervalSinceDate:self.startedAt] * 1000.0;
    //    NSLog(@"millisElapsed = %f",millisElapsed);
    [self writeVideoFrameAtTime:CMTimeMake((int64_t)millisElapsed, 1000) addImage:cgImage];
    
    UIGraphicsEndImageContext();
    CGImageRelease(cgImage);
}

- (void)writeVideoFrameAtTime:(CMTime)time addImage:(CGImageRef)newImage
{
    if (![self.videoWriterInput isReadyForMoreMediaData]) {
		NSLog(@"Not ready for video data");
	}
	else {
		@synchronized (self) {
            CVPixelBufferRef bufferRef = [self pixelBufferFromCGImage:newImage];
            BOOL success = [self.avAdaptor appendPixelBuffer:bufferRef withPresentationTime:time];
            if (!success) {
                NSLog(@"Warning:  Unable to write buffer to video");
            }
            
            if (self.progressBlock) {
                self.progressBlock(bufferRef, time);
            }
            CVPixelBufferRelease(bufferRef);
		}
	}
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image{
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       image);
    
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (CMSampleBufferRef)sampleBufferFromCGImage:(CVPixelBufferRef)pixelBuffer
{
    CMSampleBufferRef newSampleBuffer = NULL;
    CMSampleTimingInfo timimgInfo = kCMTimingInfoInvalid;
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(
                                                 NULL, pixelBuffer, &videoInfo);
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pixelBuffer,
                                       true,
                                       NULL,
                                       NULL,
                                       videoInfo,
                                       &timimgInfo,
                                       &newSampleBuffer);
    
    return newSampleBuffer;
}

- (NSString*)tempFilePath {
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths lastObject] stringByAppendingPathComponent:kFileName];
	
	return filePath;
}

- (void)setUpWriter {
    
    CGSize size = self.frontWindow.frame.size;
    //Clear Old TempFile
	NSError  *error = nil;
    NSString *filePath=[self tempFilePath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:filePath])
    {
		if ([fileManager removeItemAtPath:filePath error:&error] == NO)
        {
            if (self.completeBlock) {
                NSError *tmpError = [NSError errorWithDomain:kKSCCaptureErrorDomain code:AVErrorFileFailedToParse userInfo:error.userInfo];
                self.completeBlock(nil, tmpError);
                [self cleanupWriter];
                return ;
            }
		}
	}
    
    //Configure videoWriter
    NSURL   *fileUrl=[NSURL fileURLWithPath:filePath];
	self.videoWriter = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeMPEG4 error:&error];
	NSParameterAssert(self.videoWriter);
	
	// Configure videoWriterInput
    // 设置视频固定尺寸，不会随播放器的大小改变
//    NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
//                                                [NSNumber numberWithInt:size.width*2], AVVideoCleanApertureWidthKey,
//                                                [NSNumber numberWithInt:size.height*2], AVVideoCleanApertureHeightKey,
//                                                [NSNumber numberWithInt:0], AVVideoCleanApertureHorizontalOffsetKey,
//                                                [NSNumber numberWithInt:0], AVVideoCleanApertureVerticalOffsetKey,
//                                                nil];
    
    // 设置比特率/码率
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithInt:1500000], AVVideoAverageBitRateKey,
                                   [NSNumber numberWithInt:1],AVVideoMaxKeyFrameIntervalKey, // 每帧都是关键帧
//                                   videoCleanApertureSettings, AVVideoCleanApertureKey,
                                   //videoAspectRatioSettings, AVVideoPixelAspectRatioKey,
//                                   AVVideoProfileLevelH264Baseline41, AVVideoProfileLevelKey,
                                   nil];
	
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
								   AVVideoCodecH264, AVVideoCodecKey,
								   [NSNumber numberWithInt:size.width*2], AVVideoWidthKey,
								   [NSNumber numberWithInt:size.height*2], AVVideoHeightKey,
								   videoCompressionProps, AVVideoCompressionPropertiesKey,
								   nil];

	self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
	
	NSParameterAssert(self.videoWriterInput);
	self.videoWriterInput.expectsMediaDataInRealTime = YES;
	NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
	
	self.avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
	
	//add input
    [self.videoWriter addInput:self.videoWriterInput];
	[self.videoWriter startWriting];
	[self.videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
}

- (void)cleanupWriter {
   
	self.avAdaptor = nil;
	
	self.videoWriterInput = nil;
	
	self.videoWriter = nil;
	
	self.startedAt = nil;
    
    self.timer = nil;
}

- (void)completeRecordingSession {
    
	[self.videoWriterInput markAsFinished];
	
    __weak KSCCapture *weakSelf = self;
    [self.videoWriter finishWritingWithCompletionHandler:^{
        switch (weakSelf.videoWriter.status) {
            case AVAssetWriterStatusUnknown:
                break;
            case AVAssetWriterStatusWriting:
                break;
            case AVAssetWriterStatusCompleted:
                if (weakSelf.completeBlock) {
                    weakSelf.completeBlock([weakSelf tempFilePath], nil);
                }
                break;
            case AVAssetWriterStatusCancelled:
                break;
            case AVAssetWriterStatusFailed:
                if (weakSelf.completeBlock) {
                    weakSelf.completeBlock(nil, weakSelf.videoWriter.error);
                }
                break;
        }
        [weakSelf cleanupWriter];
    }];
}


@end
