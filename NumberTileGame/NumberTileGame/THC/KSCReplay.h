//
//  KSCReplay.h
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^KSCReplayProgressBlock)();

@interface KSCReplay : NSObject

@property (nonatomic, copy, nullable)

/**
 *  创建默认配置的 KSCReplay 实例
 *
 *  @discussion 非单例对象
 */
+ (instancetype)defaultReplay;

/**
 *  根据 frameRate 创建 KSCReplay 实例
 *
 *  @param frameRate 视频录制帧速FPS
 */
- (instancetype)initWithFrameRate:(NSUInteger)frameRate;

/**
 *  开始录制
 */
- (void)start;

/**
 *  结束录制
 */
- (void)cancel;

@end
NS_ASSUME_NONNULL_END