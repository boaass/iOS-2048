//
//  KSCRecord.m
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//

#import "KSCRecord.h"

static NSString *kKSCRecoderDefaultfileName = @"KSCRecord";

@interface KSCRecord ()

@property (nonatomic, strong) AVAudioRecorder *recorder;

@property (nonatomic, readwrite, copy) NSString *fileName;

@property (nonatomic, readwrite, copy) NSString *recordFilePath;

@property (nonatomic, readwrite, assign) KSCRecordStatus recordStatus;

@end

@implementation KSCRecord

- (NSString *)fileName
{
    if (!_fileName || (_fileName.length == 0)) {
        _fileName = kKSCRecoderDefaultfileName;
    }
    return _fileName;
}

+ (instancetype)defaultRecorder
{
    return [[self alloc] initWithFileName:kKSCRecoderDefaultfileName];
}

- (instancetype)init
{
    return [self initWithFileName:nil];
}

- (instancetype)initWithFileName:(nullable NSString *)fileName
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    //设置文件名和录音路径
    self.fileName = fileName;
    self.recordFilePath = [self getPathByFileName:self.fileName ofType:@"wav"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.recordFilePath]){
        [fileManager removeItemAtPath:self.recordFilePath error:nil];
    }
    
    self.recordStatus = KSCRecordStatusUnknow;
    
    return self;
}

#pragma mark - 录音开始
-(void)startRecord
{
    //初始化录音
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL URLWithString:[self.recordFilePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]
                                                settings:[self getAudioRecorderSettingDict]
                                                   error:nil];
    self.recorder.meteringEnabled = YES;
    [self.recorder prepareToRecord];
    
    //开始录音
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    [self.recorder record];
    
    self.recordStatus = KSCRecordStatusRecording;
}

#pragma mark - 录音暂停
-(void)pauseRecord
{
    if (self.recorder.isRecording) {
        [self.recorder pause];
    }

    self.recordStatus = KSCRecordStatusPaused;
}

#pragma mark - 录音结束
- (void)endRecord
{
    if (self.recorder.isRecording||(!self.recorder.isRecording && (self.recordStatus == KSCRecordStatusPaused))) {
        [self.recorder stop];
    }
    self.recordStatus = KSCRecordStatusUnknow;
    
    if (self.completeBlock) {
        self.completeBlock(self.recordFilePath, nil);
    }
}

- (NSString*)getPathByFileName:(NSString *)fileName ofType:(NSString *)type
{
    NSString* fileDirectory = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0]stringByAppendingPathComponent:fileName]stringByAppendingPathExtension:type];
    return fileDirectory;
}

- (NSDictionary*)getAudioRecorderSettingDict
{
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 8000.0],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,//通道的数目
                                   nil];
    return recordSetting;
}


@end
