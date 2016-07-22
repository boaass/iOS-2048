//
//  KSCReplay.m
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//
//

#import "KSCReplay.h"
#import "KSCCapture.h"
#import "KSCRecord.h"

static NSUInteger kKSCReplayDefaultRate = 10;

@interface KSCReplay ()

// 录屏操作实例对象
@property (nonatomic, strong) KSCCapture *capture;

// 录音操作实例对象
@property (nonatomic, strong) KSCRecord *record;

@end

@implementation KSCReplay

+ (instancetype)defaultReplay
{
    return [[self alloc] initWithFrameRate:kKSCReplayDefaultRate];
}

- (instancetype)initWithFrameRate:(NSUInteger)frameRate
{
    NSParameterAssert(frameRate > 0);
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.capture = [[KSCCapture alloc] initWithFrameRate:frameRate];
    self.record = [KSCRecord defaultRecorder];
    
    return self;
}

- (void)start
{
    
}

- (void)cancel
{
    
}

@end
