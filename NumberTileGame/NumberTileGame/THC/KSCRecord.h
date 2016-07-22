//
//  KSCRecord.h
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AudioToolbox/AudioToolbox.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^KSCRecordComplete)( NSString * _Nullable filePath, NSError * _Nullable error);

typedef NS_ENUM(NSUInteger, KSCRecordStatus) {
    KSCRecordStatusUnknow, //默认状态，未开始
    KSCRecordStatusRecording, //正在录音
    KSCRecordStatusPaused, //录音暂停
};

@interface KSCRecord : NSObject

/**
 *  录音文件名，无后缀
 */
@property (readonly) NSString *fileName;

/**
 *  录音状态
 */
@property (readonly) KSCRecordStatus recordStatus;

/**
 *  录音完成回调
 */
@property (nonatomic, copy) KSCRecordComplete completeBlock;

/**
 *  创建KSCRecord 实例
 *
 *  @discussion 非单例
 */
+ (instancetype)defaultRecorder;

/**
 *  根据fileName 创建KSCRecord 实例
 *
 *  @param fileName 不需要传后缀
 */
- (instancetype)initWithFileName:(nullable NSString *)fileName NS_DESIGNATED_INITIALIZER;

/**
 *  开始录音
 */
- (void)startRecord;


/**
 *  暂停录音
 */
-(void)pauseRecord;

/**
 *  结束录音
 */
- (void)endRecord;

@end

NS_ASSUME_NONNULL_END
