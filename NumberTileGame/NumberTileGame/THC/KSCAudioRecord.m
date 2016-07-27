//
//  KSCAudioRecord.m
//  KSCAudioRecord
//
//  Created by zcl_kingsoft on 16/7/25.
//  Copyright © 2016年 zcl_kingsoft. All rights reserved.
//

#import "KSCAudioRecord.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

/**
 *  缓存区的个数，一般3个
 */
#define kKSCAudioRecordQueueBufferNumber 3
/**
 *  采样率，要转码为amr的话必须为8000
 */
#define kKSCAudioRecordDefaultSampleRate 8000
/**
 *  输入buffer区大小
 */
#define kKSCAudioRecordDefaultInputBufferSize 5000

/**
 *  输出buffer区大小
 */
#define kKSCAudioRecordDefaultOutputBufferSize 5000

typedef NS_ENUM(NSUInteger, KSCAudioRecordState) {
    KSCAudioRecordStateNormal = 0,
    KSCAudioRecordStateRecording,
    KSCAudioRecordStatePausing,
};
typedef NS_ENUM(NSUInteger, KSCAudioPlayState) {
    KSCAudioPlayStateNormal = 0,
    KSCAudioPlayStatePlaying,
    KSCAudioPlayStatePausing,
};

// 流设置
AudioStreamBasicDescription  m_audioDescription;
// 实例对象
KSCAudioRecord *m_record = nil;
@interface KSCAudioRecord ()
{
    // 缓冲区
    AudioQueueBufferRef     _inputBuffers[kKSCAudioRecordQueueBufferNumber];
    AudioQueueBufferRef     _outputBuffers[kKSCAudioRecordQueueBufferNumber];
}

@property (nonatomic, assign, readwrite) KSCAudioRecordOptions options;
// 音频数据
@property (nonatomic, strong) NSMutableArray *totalAudioBufferData;
// audio queue
@property (nonatomic, assign) AudioQueueRef inputQueue;
@property (nonatomic, assign) AudioQueueRef outputQueue;
// 录制、播放状态
@property (nonatomic, assign) KSCAudioRecordState recordState;
@property (nonatomic, assign) KSCAudioPlayState playState;

@end

@implementation KSCAudioRecord

- (instancetype)init
{
    m_audioDescription = ksc_createAudioDescription();
    m_record = [self initWithAudioDescription:m_audioDescription options:KSCAudioRecordOptionEnableInput | KSCAudioRecordOptionEnableOutput];
    return m_record;
}

+ (instancetype)defaultAudioRecord
{
    m_audioDescription = ksc_createAudioDescription();
    m_record = [[self alloc] initWithAudioDescription:m_audioDescription options:KSCAudioRecordOptionEnableInput | KSCAudioRecordOptionEnableOutput];
    return m_record;
}

- (instancetype)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription
{
    m_record = [self initWithAudioDescription:audioDescription options:KSCAudioRecordOptionEnableInput | KSCAudioRecordOptionEnableOutput];
    return m_record;
}

- (instancetype)initWithAudioDescription:(AudioStreamBasicDescription)audioDescription options:(KSCAudioRecordOptions)options
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    m_audioDescription = audioDescription;
    self.options = options;
    _totalAudioBufferData = [NSMutableArray array];
    _volume = 1.0;
    
    _recordState = KSCAudioRecordStateNormal;
    _playState = KSCAudioPlayStateNormal;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
    
    return self;
}

#pragma mark - record
- (void)startRecord
{
    if (_recordState == KSCAudioRecordStatePausing) {
        AudioQueueStart(_inputQueue, NULL);
        return;
    }
    if (_recordState == KSCAudioRecordStateRecording) {
        return;
    }
    
    //创建一个录制音频队列
    AudioQueueNewInput(&m_audioDescription, ksc_AudioRecordInputCallback, (__bridge void *)self, NULL, NULL, 0, &_inputQueue);
    
    // 监听属性变化
    // 如果在AudioQueueStart调用后到AudioQueue真正开始运作前的这段时间内调用AudioQueueDispose方法的话会导致程序卡死。
    OSStatus status = AudioQueueAddPropertyListener(_inputQueue, kAudioQueueProperty_IsRunning, &ksc_AudioRecordInputIsRuningCallback, (__bridge void *)(self));
    if (status != noErr)
    {
        AudioQueueDispose(_inputQueue, YES);
        _inputQueue = NULL;
        return;
    }
    //设置话筒属性
    [self initSession];
    //创建录制音频队列缓冲区
    for (int index = 0; index < kKSCAudioRecordQueueBufferNumber; index++) {
        AudioQueueAllocateBuffer(_inputQueue, kKSCAudioRecordDefaultInputBufferSize, &_inputBuffers[index]);
        
        AudioQueueEnqueueBuffer(_inputQueue, _inputBuffers[index], 0, NULL);
    }
    //开启录制队列
    AudioQueueStart(_inputQueue, NULL);
}

- (void)stopRecord
{
    if (_recordState == KSCAudioPlayStateNormal) {
        return;
    }
    
    AudioQueueDispose(_inputQueue, YES);
    ksc_clearAudioRecordData();
    _recordState = KSCAudioRecordStateNormal;
}

- (void)pauseRecord
{
    if (_recordState != KSCAudioRecordStateRecording) {
        return;
    }
    AudioQueuePause(_inputQueue);
    _recordState = KSCAudioRecordStatePausing;
}

#pragma mark - playback
- (void)playAudio
{
    if (_playState == KSCAudioPlayStatePausing) {
        AudioQueueStart(_outputQueue, NULL);
        return;
    }
    if (_playState == KSCAudioPlayStatePlaying) {
        return;
    }
    //创建一个输出队列
    AudioQueueNewOutput(&m_audioDescription, ksc_AudioRecordOutputCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0,&_outputQueue);
    
    // 监听属性变化
    // 如果在AudioQueueStart调用后到AudioQueue真正开始运作前的这段时间内调用AudioQueueDispose方法的话会导致程序卡死。
    OSStatus status = AudioQueueAddPropertyListener(_outputQueue, kAudioQueueProperty_IsRunning, &ksc_AudioRecordInputIsRuningCallback, (__bridge void *)(self));
    if (status != noErr)
    {
        AudioQueueDispose(_outputQueue, YES);
        _outputQueue = NULL;
        return;
    }
    
    [self initSession];
    
    for (int index = 0; index < kKSCAudioRecordQueueBufferNumber; index++) {
        AudioQueueAllocateBuffer(_outputQueue, kKSCAudioRecordDefaultOutputBufferSize, &_outputBuffers[index]);
    }
    for (int index = 0; index < kKSCAudioRecordQueueBufferNumber; index++) {
        ksc_clearBuffer(_outputBuffers[index]);
        AudioQueueEnqueueBuffer(_outputQueue, _outputBuffers[index], 0, NULL);
    }
    //开启播放队列
    AudioQueueStart(_outputQueue, NULL);
}

- (void)pausePlay
{
    if (_playState != KSCAudioPlayStatePlaying) {
        return;
    }
    AudioQueuePause(_outputQueue);
    _playState = KSCAudioPlayStatePausing;
}

- (void)stopPlay
{
    if (_playState == KSCAudioRecordStateNormal) {
        return;
    }
    AudioQueueDispose(_outputQueue, YES);
    ksc_clearAudioRecordData();
    _playState = KSCAudioPlayStateNormal;
}

- (void)setVolume:(float)volume
{
    if (volume < 0) {
        _volume = 0;
    } else if (volume > 1.0) {
        _volume = 1;
    } else {
        _volume = volume;
    }
    
    if (!_outputQueue) {
        return;
    }
    
    AudioQueueSetParameter(_outputQueue, kAudioQueueParam_Volume, _volume);
}

//初始化会话
- (void)initSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    BOOL enableInput = self.options & KSCAudioRecordOptionEnableInput;
    BOOL enableOutput = self.options & KSCAudioRecordOptionEnableOutput;
    NSString *audioSessionCategory = enableInput ? (enableOutput ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryRecord) : AVAudioSessionCategoryPlayback;
    NSError *error = nil;
    //设置audioSession格式 录音播放模式
    [[AVAudioSession sharedInstance] setCategory:audioSessionCategory withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

AudioStreamBasicDescription ksc_createAudioDescription()
{
    AudioStreamBasicDescription audioDescription;
    //重置下
    memset(&audioDescription, 0, sizeof(audioDescription));
    
    //设置采样率
    //采样率的意思是每秒需要采集的帧数
    audioDescription.mSampleRate = kKSCAudioRecordDefaultSampleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数
    audioDescription.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    //设置format，怎么称呼不知道。
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    
    if (audioDescription.mFormatID == kAudioFormatLinearPCM){
        
        audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        audioDescription.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
        audioDescription.mFramesPerPacket = 1;
    }
    return audioDescription;
}

//录音回调
void ksc_AudioRecordInputCallback (
                           void                                *inUserData,
                           AudioQueueRef                       inAQ,
                           AudioQueueBufferRef                 inBuffer,
                           const AudioTimeStamp                *inStartTime,
                           UInt32                              inNumberPackets,
                           const AudioStreamPacketDescription  *inPacketDescs
                           )
{
    NSLog(@"录音回调------");
    if (inNumberPackets > 0) {
        NSData *pcmData = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        NSLog(@"录音回调------pcmData = %lu", (unsigned long)pcmData.length);
        if (pcmData && pcmData.length > 0) {
            if ([pcmData isKindOfClass:[NSData class]]) {
                [m_record.totalAudioBufferData addObject:pcmData];
            } else {
                NSLog(@"inBuffer mAudioData = %@, mAudioDataByteSize = %u", inBuffer->mAudioData, (unsigned int)inBuffer->mAudioDataByteSize);
                NSLog(@"pcmData error content:%@", [pcmData class]);
            }
        }
        
        if (m_record.recordProcessBlock) {
            m_record.recordProcessBlock(pcmData);
        }
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

//播放录音回调
void ksc_AudioRecordOutputCallback (
                            void                 *inUserData,
                            AudioQueueRef        inAQ,
                            AudioQueueBufferRef  inBuffer
                            )
{
    NSLog(@"播放回调-------");
    NSLog(@"count = %ld", [m_record.totalAudioBufferData count]);
    if ([m_record.totalAudioBufferData count] > 0) {
        // 录音数据队列中内容过多导致播放延迟，留5条数据
        if ([m_record.totalAudioBufferData count] > 5) {
            [m_record.totalAudioBufferData removeObjectsInRange:NSMakeRange(0, m_record.totalAudioBufferData.count - 1)];
        }
        
        NSData *pcmData = [m_record.totalAudioBufferData firstObject];
        NSLog(@"播放回调------pcmData = %lu", (unsigned long)pcmData.length);
        if (![pcmData isKindOfClass:[NSData class]]) {
            NSLog(@"inBuffer in array mAudioData = %@, mAudioDataByteSize = %u", inBuffer->mAudioData, (unsigned int)inBuffer->mAudioDataByteSize);
            NSLog(@"pcmData error content in array:%@", [pcmData class]);
        }
        if (pcmData && pcmData.length < 10000) {
            memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);
            inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
            inBuffer->mPacketDescriptionCount = 0;
        }
        [m_record.totalAudioBufferData removeObjectAtIndex:0];
        if (m_record.playProcessBlock) {
            m_record.playProcessBlock(pcmData);
        }
    } else {
        ksc_clearBuffer(inBuffer);
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

//AudioQueue start call back
void ksc_AudioRecordInputIsRuningCallback(
                                    void * __nullable       inUserData,
                                    AudioQueueRef           inAQ,
                                    AudioQueuePropertyID    inID
                                    )
{
    if (inID == kAudioQueueProperty_IsRunning) {
        UInt32 ioDataSize = 0;
        int runState = 0;
        if (inAQ == m_record.inputQueue) {
            AudioQueueGetProperty(inAQ, inID, &runState, &ioDataSize);
            if (runState == 1) {
                m_record.recordState = KSCAudioRecordStateRecording;
            }
        } else if (inAQ == m_record.outputQueue) {
            AudioQueueGetProperty(inAQ, inID, &runState, &ioDataSize);
            if (runState == 1) {
                m_record.playState = KSCAudioPlayStatePlaying;
            }
        }
    }
    
}

//清空缓冲区
void ksc_clearBuffer(AudioQueueBufferRef buffer)
{
    for (int i=0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
    }
}

//清除数据
void ksc_clearAudioRecordData()
{
    [m_record.totalAudioBufferData removeAllObjects];
}

#pragma mark - AVAudioSessionRouteChangeNotification
- (void)audioSessionRouteChange:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    int changeReason = [userInfo[AVAudioSessionRouteChangeReasonKey] intValue];
    //等于AVAudioSessionRouteChangeReasonOldDeviceUnavailable表示旧输出不可用
    if (changeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *routeDescription = userInfo[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *portDescription = [routeDescription.outputs firstObject];
        //原设备为耳机则暂停
        if ([portDescription.portType isEqualToString:@"Headphones"]) {
            
        }
    }
}

@end
