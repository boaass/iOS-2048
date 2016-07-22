//
//  KSCCapture.h
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "KSCCaptureUtilities.h"

NS_ASSUME_NONNULL_BEGIN
// 录制过程中
typedef void (^CaptureProgressBlock)(CVPixelBufferRef pixelBufferRef, CMTime time);
// 录制完成
typedef void (^CaptureCompleteBlock)(NSString * _Nullable filePath, NSError * _Nullable error);

@interface KSCCapture : NSObject
/**
 *  帧速
 */
@property (nonatomic, assign) NSUInteger frameRate;

/**
 *  录制过程中block
 */
@property (nonatomic, copy, nullable) CaptureProgressBlock progressBlock;

/**
 *  录制完成block
 */
@property (nonatomic, copy, nullable) CaptureCompleteBlock completeBlock;

/**
 *  创建默认配置的 KSCCapture 实例
 *
 *  @discussion 非单例
 */
+ (instancetype)defaultRecorder;

/**
 *  根据frameRate 创建 KSCCapture 实例
 */
- (instancetype)initWithFrameRate:(NSUInteger)frameRate NS_DESIGNATED_INITIALIZER;

/**
 *  开始录制
 */
- (void)startRecording;

/**
 *  结束录制
 */
- (void)stopRecording;

@end
NS_ASSUME_NONNULL_END
