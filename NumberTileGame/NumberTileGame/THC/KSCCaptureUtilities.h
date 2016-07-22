//
//  KSCCaptureUtilities.h
//  KSCReplay
//
//  Created by zcl_kingsoft on 16/7/22.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>

@interface KSCCaptureUtilities : NSObject

// 音频与视频的合并. action的形式如下:
// - (void)mergedidFinish:(NSString *)videoPath WithError:(NSError *)error;
+ (void)mergeVideo:(NSString *)videoPath andAudio:(NSString *)audioPath andTarget:(id)target andAction:(SEL)action;

@end
