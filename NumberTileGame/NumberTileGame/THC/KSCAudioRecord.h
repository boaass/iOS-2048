//
//  KSCAudioRecord.h
//  KSCAudioRecord
//
//  Created by zcl_kingsoft on 16/7/25.
//  Copyright © 2016年 zcl_kingsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, KSCAudioRecordOptions) {
    /// Whether to enable audio input from the microphone or another input device.
    KSCAudioRecordOptionEnableInput              = 1 << 0,
    /// Whether to enable audio output.
    KSCAudioRecordOptionEnableOutput             = 1 << 1
};

/**
 *  录制过程
 *
 *  @param data pcm数据
 */
typedef void (^KSCAudioRecordProcessBlock)(NSData *data);

/**
 *  播放过程
 *
 *  @param data pcm数据
 */
typedef void (^KSCAudioPlayProcessBlock)(NSData *data);


@interface KSCAudioRecord : NSObject

/**
 *  录音相关配置
 */
@property (readonly) KSCAudioRecordOptions options;

/**
 *  播放音量
 *  from 0.0 to 1.0.
 */
@property (nonatomic, assign) float volume;

/**
 *  录制过程回调
 */
@property (nonatomic, copy, nullable) KSCAudioRecordProcessBlock recordProcessBlock;

/**
 *  播放过程回调
 */
@property (nonatomic, copy, nullable) KSCAudioPlayProcessBlock playProcessBlock;

/**
 *  返回默认配置的KSCAudioRecord实例
 *
 *  @warning: 非单例
 */
+ (instancetype)defaultAudioRecord;

/**
 *  返回KSCAudioRecord实例
 *
 *  @param audioDescription 录音相关配置
 *
 *  @warning:默认为 KSCAudioRecordOptionEnableInput | KSCAudioRecordOptionEnableOutput
 */
- (instancetype)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription;

/**
 *  返回KSCAudioRecord实例
 *
 *  @param audioDescription 录音相关配置
 *  @param options          录音播放模式
 */
- (instancetype)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription options:(KSCAudioRecordOptions)options NS_DESIGNATED_INITIALIZER;

/**
 *  录制开始
 */
- (void)startRecord;

/**
 *  停止录制
 */
- (void)stopRecord;

/**
 *  暂停录制
 */
- (void)pauseRecord;

/**
 *  播放录音
 */
- (void)playAudio;

/**
 *  暂停播放
 */
- (void)pausePlay;

/**
 *  停止播放
 */
- (void)stopPlay;

@end
NS_ASSUME_NONNULL_END
