//
//  UpYunLivePusher.m
//  libLivePush
//
//  Created by nearwmy on 2018/7/12.
//  Copyright © 2018年 EICAPITAN. All rights reserved.
//

#import "UpYunLivePusher.h"
#import "PGLivePush.h"
#import "PDRCoreAppFrame.h"
#import "PDRCoreAppFramePrivate.h"
#import "UPLiveService/UPAVCapturer/UPAVCapturer.h"
#import <UPLiveSDKDll/UPAVStreamer.h>
#import <UPLiveSDKDll/RtcManager.h>


@interface UpYunLivePusher()<UPAVCapturerDelegate>
@property (nonatomic, retain) UIView* livePushView;
@property (nonatomic, retain) UPAVCapturer* upavCapturehandle;
@property (nonatomic, assign) UPAVCapturerPresetLevel cameraLevel;
@property (nonatomic, copy)DCLivePushHandle startPushHandle;

@end

@implementation UpYunLivePusher

- (id)initWithOption:(NSArray*)options
{
    if ([self init]) {
        NSDictionary* optionObject = [options objectAtIndex:3];
        
        _upavCapturehandle = [[UPAVCapturer alloc] init] ;
        if (_upavCapturehandle) {
            _livePushView = [_upavCapturehandle previewWithFrame:self.bounds
                                                        contentMode:UIViewContentModeScaleAspectFit];
            if (_livePushView) {
                [self addSubview:_livePushView];
            }
            _upavCapturehandle.delegate = self;
            self.bIsPlaying = NO;
        }
        [self setVideoOption:optionObject];
        
    }
    return self;
}

- (void)preview {
    [_upavCapturehandle setCamaraPosition:AVCaptureDevicePositionFront];
    [_upavCapturehandle openCamera:YES];
}


- (void)start:(DCLivePushHandle)callBackhandle{
    if (!self.bIsPlaying) {
        if (_upavCapturehandle == nil || ![self urlMatch:self.pushStreamURL]) {
            PDRPluginResult* result = [PDRPluginResult resultWithStatus:PDRCommandStatusError messageToErrorObject:1 withMessage:@"rtmp url invalidate"];
            if(callBackhandle){
                callBackhandle([result toJSONString], self.startCallbackID);
            }
        }
        _startPushHandle = callBackhandle;
        [self prepareLiveOptions];
        [_upavCapturehandle start];
        [_upavCapturehandle setCamaraPosition:AVCaptureDevicePositionFront];
        self.bIsPlaying = YES;
    }
}

- (void)stop{
    [self stop:YES];
}

- (void)stop:(BOOL)closePreview {
    if (self.bIsPlaying) {
        self.bIsPlaying = NO;
        [_upavCapturehandle stop:closePreview];
    }
}

- (void)resume{
    if (!self.bIsPlaying) {
        self.bIsPlaying = YES;
        [self prepareLiveOptions];
        [_upavCapturehandle start];
    }
}

- (void)pause{
    if (self.bIsPlaying) {
        self.bIsPlaying = NO;
        [_upavCapturehandle stop];
    }
}

- (void)close{
    if (_upavCapturehandle) {
        _upavCapturehandle.networkSateBlock = nil;
        [_upavCapturehandle stop];
        _upavCapturehandle = nil;
    }
    
    [self.pListneerArray removeAllObjects];
    self.pListneerArray = nil;
    //self.pListenEventFrame = nil;
    
    if (self.pushStreamURL) {
        self.pushStreamURL = nil;
    }
}



- (void)setVideoOption:(NSDictionary*)pOptions{
    [super setVideoOption:pOptions];
    
    if (nil != _upavCapturehandle ) {
        if ([pOptions objectForKey:@"mode"]) {
            NSString* pModeType = [pOptions objectForKey:@"mode"];
            if ([[pModeType lowercaseString] compare:@"SD"]) {
                self.liveMode = EDCLiveMode_SD;
                self.upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_480x360;
            }else if ([[pModeType lowercaseString] compare:@"HD"]){
                self.liveMode = EDCLiveMode_HD;
                self.upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_640x480;
            }else if ([[pModeType lowercaseString] compare:@"FHD"]){
                self.liveMode = EDCLiveMode_FHD;
                self.upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_960x540;
            }else if ([[pModeType lowercaseString] compare:@"RTC"]){
                self.liveMode = EDCLiveMode_RTC;
                self.upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_640x480;
            }
        }
        
        [self prepareLiveOptions];
    }
}

- (void)addEventListener:(PDRCoreAppFrame*)pFrame{
    if(self.pListneerArray == nil){
        self.pListneerArray = [[NSMutableArray alloc] initWithCapacity:0];
    }
    [self.pListneerArray addObject:pFrame];
    //self.pListenEventFrame = pFrame;
}

- (void)switchCamera{
    [_upavCapturehandle switchCamera];
}

- (void)snapshot:(void (^)(UIImage *))completion{
    [_upavCapturehandle shotPhoto:^(UIImage *photo) {
        if (completion) {
            completion(photo);
        }
    }];
}

- (void)prepareLiveOptions
{
    _upavCapturehandle.outStreamPath = self.pushStreamURL;
    
    switch (self.liveMode) {
        case EDCLiveMode_SD:
            _upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_480x360;
            break;
        case EDCLiveMode_HD:
            _upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_640x480;
            break;
        case EDCLiveMode_FHD:
            _upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_1280x720;
            break;
        case EDCLiveMode_RTC:
            _upavCapturehandle.capturerPresetLevel = UPAVCapturerPreset_640x480;
            break;
        default:
            break;
    }
    
    _upavCapturehandle.beautifyOn = self.bBeauty;
    
    _upavCapturehandle.audioMute = self.bSilence;
    
    _upavCapturehandle.audioOnly = self.bCameraEnable;
    
    _upavCapturehandle.bitrate = (self.maxbitrate + self.minbitrate)/2;
    
    __block typeof (self) weakself = self;
    _upavCapturehandle.networkSateBlock = ^(UPAVStreamerNetworkState level) {
        NSString* eventResult = nil;
        if(level == UPAVStreamerNetworkState_BAD){
            eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 1102, @"网络断连, 已启动自动重连"];
        }else if(level == UPAVStreamerNetworkState_NORMAL){
            eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 1101, @"网络状况不佳：上行带宽太小，上传数据受阻"];
            
        }else if(level == UPAVStreamerNetworkState_GOOD){
            eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 1002, @"connected"];
        }
        [weakself dispatchListenerEvent:eventResult EventType:@"netstatus"];
    };
    
    // 设置美白需要写一个过滤器
    if (self.bWhiteCat){
        GPUImageBrightnessFilter* filter = [[GPUImageBrightnessFilter alloc] init];
        if (filter){
            filter.brightness = 0.3f;
            [_upavCapturehandle setFilter:filter];
        }
    }
}

#pragma mark - delegates

- (void)streamer:(UPAVStreamer *)streamer statusDidChange:(UPAVStreamerStatus)status error:(NSError *)error
{
    NSString* eventResult = nil;
    
    switch (status) {
        case UPAVStreamerStatusConnecting: {
            eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 1001, error==nil?@"connecting...":error.localizedDescription];
        }
            break;
        case UPAVStreamerStatusWriting: {
        }
            break;
        case UPAVStreamerStatusConnected: {
            eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 1002, error==nil?@"connected...":error.localizedDescription];
            if (self.startCallbackID) {
                PDRPluginResult* result = [PDRPluginResult resultWithStatus:PDRCommandStatusOK messageAsInt:0];
                result.keepCallback = YES;
                _startPushHandle([result toJSONString], self.startCallbackID);
                self.startCallbackID = NULL;
            }
        }
            break;
        case UPAVStreamerStatusWriteError: {
        }
            break;
        case UPAVStreamerStatusOpenError: {
        }
            break;
        case UPAVStreamerStatusClosed: {
        }
            break;
        case UPAVStreamerStatusIdle: {
        }
            break;
    }
    
    if(eventResult){
        [self dispatchListenerEvent:eventResult EventType:EventType];
    }
}

- (void)dispatchListenerEvent:(NSString*)resuestStr EventType:(NSString*)EventType{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* ListenerEventString = [NSString stringWithFormat:EVENT_TEMPLATE, EventType, resuestStr];
        for (PDRCoreAppFrame* pListenerFrame in self.pListneerArray) {
            [pListenerFrame evaluateJavaScript:ListenerEventString completionHandler:nil];
        }
        
    });
}

/// 采集状态回调
- (void)capturer:(UPAVCapturer *)capturer capturerStatusDidChange:(UPAVCapturerStatus)capturerStatus{
    NSLog(@"capturerStatusDidChange %d", (int)capturer);
}
/// 错误回调
- (void)capturer:(UPAVCapturer *)capturer capturerError:(NSError *)error{
    NSLog(@"capturerError %@", error.localizedDescription);
    if (self.startCallbackID) {
        PDRPluginResult* result = [PDRPluginResult resultWithStatus:PDRCommandStatusError messageToErrorObject:2 withMessage:error.localizedDescription];
        _startPushHandle([result toJSONString], self.startCallbackID);
        self.startCallbackID = NULL;
    }
}
/// 推流状态回调
- (void)capturer:(UPAVCapturer *)capturer pushStreamStatusDidChange:(UPPushAVStreamStatus)streamStatus{
    NSLog(@"pushStreamStatusDidChange %d", (int)streamStatus);
    if (streamStatus == UPPushAVStreamStatusClosed) {
        NSString* eventResult = [NSString stringWithFormat:EVENT_RESULT_TEMPLATE, 3004, @"rtmp disconnected"];
        [self dispatchListenerEvent:eventResult EventType:EventType];
    }
}

//连麦回调
- (void)capturer:(UPAVCapturer *)capturer rtcDidJoinedOfUid:(NSUInteger)uid{
    NSLog(@"rtcDidJoinedOfUid %d", (int)uid);
}
//连麦回调
- (void)capturer:(UPAVCapturer *)capturer rtcDidOfflineOfUid:(NSUInteger)uid reason:(NSUInteger)reason{
    NSLog(@"rtcDidOfflineOfUid 2 %d", (int)uid);
}
//连麦回调
- (void)capturer:(UPAVCapturer *)capturer rtcDidOccurWarning:(NSUInteger)warningCode{
    NSLog(@"rtcDidOccurWarning %d", (int)warningCode);
}
//连麦回调
- (void)capturer:(UPAVCapturer *)capturer rtcDidOccurError:(NSUInteger)errorCode{
    NSLog(@"rtcDidOccurError %d", (int)errorCode);
}
//连麦回调
- (void)capturer:(UPAVCapturer *)capturer rtcConnectionDidLost:(id)rtcmanager{
    NSLog(@"rtcConnectionDidLost %@", rtcmanager);
}
@end
