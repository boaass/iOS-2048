//
//  F3HNumberTileGameViewController.m
//  NumberTileGame
//
//  Created by Austin Zheng on 3/22/14.
//
//

#import "F3HNumberTileGameViewController.h"

#import "F3HGameboardView.h"
#import "F3HControlView.h"
#import "F3HScoreView.h"
#import "F3HGameModel.h"

#import "KSCCapture.h"
#import "KSCRecord.h"

#define ELEMENT_SPACING 10

#define VEDIOPATH @"vedioPath"

@interface F3HNumberTileGameViewController () <F3HGameModelProtocol, F3HControlViewProtocol,AVAudioRecorderDelegate>
{
    KSCCapture *capture;
    KSCRecord *audioRecord;
}

@property (nonatomic, strong) F3HGameboardView *gameboard;
@property (nonatomic, strong) F3HGameModel *model;
@property (nonatomic, strong) F3HScoreView *scoreView;
@property (nonatomic, strong) F3HControlView *controlView;

@property (nonatomic) BOOL useScoreView;
@property (nonatomic) BOOL useControlView;

@property (nonatomic) NSUInteger dimension;
@property (nonatomic) NSUInteger threshold;

@property (nonatomic, copy) NSString *capturePath;
@property (nonatomic, copy) NSString *audioRecordPath;
@end

@implementation F3HNumberTileGameViewController

//- (void)setCapturePath:(NSString *)capturePath
//{
//    [self willChangeValueForKey:@"capturePath"];
//    _capturePath = [capturePath copy];
//    [self didChangeValueForKey:@"capturePath"];
//}
//
//- (void)setAudioRecordPath:(NSString *)audioRecordPath
//{
//    [self willChangeValueForKey:@"audioRecordPath"];
//    _audioRecordPath = [audioRecordPath copy];
//    [self didChangeValueForKey:@"audioRecordPath"];
//}

+ (instancetype)numberTileGameWithDimension:(NSUInteger)dimension
                               winThreshold:(NSUInteger)threshold
                            backgroundColor:(UIColor *)backgroundColor
                                scoreModule:(BOOL)scoreModuleEnabled
                             buttonControls:(BOOL)buttonControlsEnabled
                              swipeControls:(BOOL)swipeControlsEnabled {
    F3HNumberTileGameViewController *c = [[self class] new];
    c.dimension = dimension > 2 ? dimension : 2;
    c.threshold = threshold > 8 ? threshold : 8;
    c.useScoreView = scoreModuleEnabled;
    c.useControlView = buttonControlsEnabled;
    c.view.backgroundColor = backgroundColor ?: [UIColor whiteColor];
    if (swipeControlsEnabled) {
        [c setupSwipeControls];
    }
    return c;
}

#pragma mark - Controller Lifecycle

- (void)setupSwipeControls {
    UISwipeGestureRecognizer *upSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(upButtonTapped)];
    upSwipe.numberOfTouchesRequired = 1;
    upSwipe.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:upSwipe];
    
    UISwipeGestureRecognizer *downSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(downButtonTapped)];
    downSwipe.numberOfTouchesRequired = 1;
    downSwipe.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:downSwipe];
    
    UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(leftButtonTapped)];
    leftSwipe.numberOfTouchesRequired = 1;
    leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:leftSwipe];
    
    UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(rightButtonTapped)];
    rightSwipe.numberOfTouchesRequired = 1;
    rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:rightSwipe];
}

- (void)setupGame {
    F3HScoreView *scoreView;
    F3HControlView *controlView;
    
    CGFloat totalHeight = 0;
    
    // Set up score view
    if (self.useScoreView) {
        scoreView = [F3HScoreView scoreViewWithCornerRadius:6
                                            backgroundColor:[UIColor darkGrayColor]
                                                  textColor:[UIColor whiteColor]
                                                   textFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:16]];
        totalHeight += (ELEMENT_SPACING + scoreView.bounds.size.height);
        self.scoreView = scoreView;
    }
    
    // Set up control view
    if (self.useControlView) {
        controlView = [F3HControlView controlViewWithCornerRadius:6
                                                  backgroundColor:[UIColor blackColor]
                                                  movementButtons:YES
                                                       exitButton:NO
                                                         delegate:self];
        totalHeight += (ELEMENT_SPACING + controlView.bounds.size.height);
        self.controlView = controlView;
    }
    
    // Create gameboard
    CGFloat padding = (self.dimension > 5) ? 3.0 : 6.0;
    CGFloat cellWidth = floorf((230 - padding*(self.dimension+1))/((float)self.dimension));
    if (cellWidth < 30) {
        cellWidth = 30;
    }
    F3HGameboardView *gameboard = [F3HGameboardView gameboardWithDimension:self.dimension
                                                                 cellWidth:cellWidth
                                                               cellPadding:padding
                                                              cornerRadius:6
                                                           backgroundColor:[UIColor blackColor]
                                                           foregroundColor:[UIColor darkGrayColor]];
    totalHeight += gameboard.bounds.size.height;
    
    // Calculate heights
    CGFloat currentTop = 0.5*(self.view.bounds.size.height - totalHeight);
    if (currentTop < 0) {
        currentTop = 0;
    }
    
    if (self.useScoreView) {
        CGRect scoreFrame = scoreView.frame;
        scoreFrame.origin.x = 0.5*(self.view.bounds.size.width - scoreFrame.size.width);
        scoreFrame.origin.y = currentTop;
        scoreView.frame = scoreFrame;
        [self.view addSubview:scoreView];
        currentTop += (scoreFrame.size.height + ELEMENT_SPACING);
    }
    
    CGRect gameboardFrame = gameboard.frame;
    gameboardFrame.origin.x = 0.5*(self.view.bounds.size.width - gameboardFrame.size.width);
    gameboardFrame.origin.y = currentTop;
    gameboard.frame = gameboardFrame;
    [self.view addSubview:gameboard];
    currentTop += (gameboardFrame.size.height + ELEMENT_SPACING);
    
    if (self.useControlView) {
        CGRect controlFrame = controlView.frame;
        controlFrame.origin.x = 0.5*(self.view.bounds.size.width - controlFrame.size.width);
        controlFrame.origin.y = currentTop;
        controlView.frame = controlFrame;
        [self.view addSubview:controlView];
    }
    
    self.gameboard = gameboard;
    
    // Create mode;
    F3HGameModel *model = [F3HGameModel gameModelWithDimension:self.dimension
                                                      winValue:self.threshold
                                                      delegate:self];
    [model insertAtRandomLocationTileWithValue:2];
    [model insertAtRandomLocationTileWithValue:2];
    self.model = model;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupGame];
    
    [self addObserver:self forKeyPath:@"capturePath" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"audioRecordPath" options:NSKeyValueObservingOptionNew context:nil];
    
    // add by zcl
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(0, 40, 100, 40)];
    [button setTitle:@"开始录制" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    button.tag = 1;
    [button addTarget:self action:@selector(recordOrStopRecord:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button1 setFrame:CGRectMake(110, 40, 100, 40)];
    [button1 setTitle:@"弹窗" forState:UIControlStateNormal];
    [button1 setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [button1 addTarget:self action:@selector(openAlerview) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
}


#pragma mark - Private API

- (void)followUp {
    // This is the earliest point the user can win
    if ([self.model userHasWon]) {
        [self.delegate gameFinishedWithVictory:YES score:self.model.score];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Victory!" message:@"You won!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    else {
        NSInteger rand = arc4random_uniform(10);
        if (rand == 1) {
            [self.model insertAtRandomLocationTileWithValue:4];
        }
        else {
            [self.model insertAtRandomLocationTileWithValue:2];
        }
        // At this point, the user may lose
        if ([self.model userHasLost]) {
            [self.delegate gameFinishedWithVictory:NO score:self.model.score];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Defeat!" message:@"You lost..." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
}


#pragma mark - Model Protocol

- (void)moveTileFromIndexPath:(NSIndexPath *)fromPath toIndexPath:(NSIndexPath *)toPath newValue:(NSUInteger)value {
    [self.gameboard moveTileAtIndexPath:fromPath toIndexPath:toPath withValue:value];
}

- (void)moveTileOne:(NSIndexPath *)startA tileTwo:(NSIndexPath *)startB toIndexPath:(NSIndexPath *)end newValue:(NSUInteger)value {
    [self.gameboard moveTileOne:startA tileTwo:startB toIndexPath:end withValue:value];
}

- (void)insertTileAtIndexPath:(NSIndexPath *)path value:(NSUInteger)value {
    [self.gameboard insertTileAtIndexPath:path withValue:value];
}

- (void)scoreChanged:(NSInteger)newScore {
    self.scoreView.score = newScore;
}


#pragma mark - Control View Protocol

- (void)upButtonTapped {
    [self.model performMoveInDirection:F3HMoveDirectionUp completionBlock:^(BOOL changed) {
        if (changed) [self followUp];
    }];
}

- (void)downButtonTapped {
    [self.model performMoveInDirection:F3HMoveDirectionDown completionBlock:^(BOOL changed) {
        if (changed) [self followUp];
    }];
}

- (void)leftButtonTapped {
    [self.model performMoveInDirection:F3HMoveDirectionLeft completionBlock:^(BOOL changed) {
        if (changed) [self followUp];
    }];
}

- (void)rightButtonTapped {
    [self.model performMoveInDirection:F3HMoveDirectionRight completionBlock:^(BOOL changed) {
        if (changed) [self followUp];
    }];
}

- (void)resetButtonTapped {
    [self.gameboard reset];
    [self.model reset];
    [self.model insertAtRandomLocationTileWithValue:2];
    [self.model insertAtRandomLocationTileWithValue:2];
}

- (void)exitButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - add by zcl
-(void)recordOrStopRecord:(UIButton *)button{
    if (button.tag==1) {
        [button setTitle:@"停止录制" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        button.tag = 2;
        [self recordMustSuccess];
    }else{
        [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        button.tag = 1;
        [button setTitle:@"开始录制" forState:UIControlStateNormal];
        [self StopRecord];
    }
}

- (void)openAlerview
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"break u" message:@"hahahhahah" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    [ac addAction:action];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)recordMustSuccess {
    if(capture == nil){
        capture=[[KSCCapture alloc] init];
    }
    capture.frameRate = 20;
    capture.progressBlock = ^(CVPixelBufferRef pixelBufferRef, CMTime time){
//        NSLog(@"capture CVPixelBufferRef = %@, time = %p", pixelBufferRef, &time);
    };
    
    __weak F3HNumberTileGameViewController *weakSelf = self;
    
    capture.completeBlock = ^(NSString *filePath, NSError *error){
        NSLog(@"capture filePath = %@, error = %@", filePath, error);
        if (!error) {
            weakSelf.capturePath = filePath;
        }
    };
    
    if (!audioRecord) {
        audioRecord = [[KSCRecord alloc] initWithFileName:VEDIOPATH];
    }
    audioRecord.completeBlock = ^(NSString *filePath, NSError *error){
        NSLog(@"audioRecord filePath = %@", filePath);
        if (!error) {
            weakSelf.audioRecordPath = filePath;
        }
    };
    
    [capture performSelector:@selector(startRecording)];
    
    [audioRecord performSelector:@selector(startRecord) withObject:nil afterDelay:0.1];
    
}

#pragma mark -
#pragma mark audioRecordDelegate
/**
 *  音频录制结束合成视频音频
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"capturePath"] || [keyPath isEqualToString:@"audioRecordPath"]) {
        if (self.capturePath && self.audioRecordPath && self.capturePath.length != 0 && self.audioRecordPath.length != 0) {
            [KSCCaptureUtilities mergeVideo:self.capturePath andAudio:self.audioRecordPath andTarget:self andAction:@selector(mergedidFinish:WithError:)];
            self.capturePath = nil;
            self.audioRecordPath = nil;
        }
    }
}

#pragma mark -
#pragma mark CustomMethod

- (void)video: (NSString *)videoPath didFinishSavingWithError:(NSError *) error contextInfo: (void *)contextInfo{
    if (error) {
        NSLog(@"---%@",[error localizedDescription]);
    }
}

- (void)mergedidFinish:(NSString *)videoPath WithError:(NSError *)error
{
    NSDateFormatter* dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:SS"];
    NSString* currentDateStr=[dateFormatter stringFromDate:[NSDate date]];
    
    NSString* fileName=[NSString stringWithFormat:@"白板录制,%@.mov",currentDateStr];
    
    NSString* path=[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@",fileName]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath])
    {
        NSError *err=nil;
        [[NSFileManager defaultManager] moveItemAtPath:videoPath toPath:path error:&err];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"allVideoInfo"]) {
        NSMutableArray* allFileArr=[[NSMutableArray alloc] init];
        [allFileArr addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"allVideoInfo"]];
        [allFileArr insertObject:fileName atIndex:0];
        [[NSUserDefaults standardUserDefaults] setObject:allFileArr forKey:@"allVideoInfo"];
    }
    else{
        NSMutableArray* allFileArr=[[NSMutableArray alloc] init];
        [allFileArr addObject:fileName];
        [[NSUserDefaults standardUserDefaults] setObject:allFileArr forKey:@"allVideoInfo"];
    }
    
    //音频与视频合并结束，存入相册中
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
        UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
}


- (void)StopRecord{
    
    [capture performSelector:@selector(stopRecording)];
    [audioRecord performSelector:@selector(endRecord)];
}

- (NSString*)getPathByFileName:(NSString *)fileName ofType:(NSString *)type
{
    NSString* fileDirectory = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0]stringByAppendingPathComponent:fileName]stringByAppendingPathExtension:type];
    return fileDirectory;
}

@end
