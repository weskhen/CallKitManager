//
//  AppCallKitManager.m
//  callkitManager
//
//  Created by wujian on 10/25/16.
//  Copyright © 2016 wesk痕. All rights reserved.
//

#import "AppCallKitManager.h"
#import <Intents/Intents.h>
#import <AVFoundation/AVFoundation.h>

@interface AppCallKitManager ()<CXProviderDelegate,CXCallObserverDelegate>

@property (nonatomic, strong) CXProvider *provider;//管理器
@property (nonatomic, strong) CXCallUpdate *callUpdate; //信息状态变换更新
@property (nonatomic, strong) CXProviderConfiguration *configuration; //定义

@property (nonatomic, strong) CXCallController *callController; //call 界面
@property (nonatomic, strong) NSUUID *currentUUID;
@property (nonatomic, assign) BOOL currentIsVideo;
@property (nonatomic, strong) NSString *currentPhoneNumber; //需要有+号

@property (nonatomic, assign) BOOL  hasOtherCall;//当前是否存在其他call //如系统电话或其他app的call
@end
@implementation AppCallKitManager

#define callQueue  dispatch_queue_create("WESKHEN_CallKitQueue", 0)
+ (AppCallKitManager*)sharedInstance
{
    static AppCallKitManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [AppCallKitManager new];
    });
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.provider = [[CXProvider alloc] initWithConfiguration:self.configuration];
        [_provider setDelegate:self queue:nil];
        [self.callController.callObserver setDelegate:self queue:callQueue];
    }
    return self;
}


//接听方 来电展示 incomingCall
- (void)showCallInComingWithName:(NSString *)userName andPhoneNumber:(NSString *)phoneNumber isVideoCall:(BOOL)isVideo
{
    
    self.currentIsVideo = isVideo;
    self.currentPhoneNumber = phoneNumber;
    
    CXHandle* handle=[[CXHandle alloc]initWithType:CXHandleTypePhoneNumber value:phoneNumber];
    self.callUpdate.remoteHandle = handle;
    _callUpdate.hasVideo = isVideo;
    _callUpdate.localizedCallerName = userName;

    self.currentUUID = [NSUUID UUID];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [_provider reportNewIncomingCallWithUUID:self.currentUUID update:self.callUpdate completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"current error %@",error.userInfo);
        }
    }];
}

//拨打方
- (void)starCallWithUserActivity:(NSUserActivity *)userActivity
{
    BOOL isVideoCall = false;
    if ([userActivity.activityType isEqualToString:@"INStartAudioCallIntent"]) {
        //voice call
        isVideoCall = false;
    }
    else if ([userActivity.activityType isEqualToString:@"INStartVideoCallIntent"])
    {
        //video call
        isVideoCall = true;
    }

    INInteraction *interaction = userActivity.interaction;
    INIntent *intent = interaction.intent;
    
    INPerson *person = nil;
    if (isVideoCall) {
        person = [(INStartVideoCallIntent *)intent contacts][0];
    }
    else
    {
        person = [(INStartAudioCallIntent *)intent contacts][0];
    }
    
    if (person.personHandle.type != INPersonHandleTypePhoneNumber) {
        return;
    }
    
    // 长按通讯录中联系人号码 person.personHandle.value 读取的是通讯录中的号码 可能不含（+区号）需要自己做简单识别判断
    if ([self.currentPhoneNumber isEqualToString:person.personHandle.value] && self.currentPhoneNumber.length > 0) {
        //同一个回话
        if (self.currentIsVideo == isVideoCall) {
            //其他的场景不处理:
            NSLog(@"同一个回话进来，且模式相同 不处理");

        }
        else
        {
            //根据实际需要来实现  是否需要改变通话性质  一般不直接更新改变 可进去到具体的界面展示后再调整是否视频
            if (self.currentIsVideo) {
                //从video转voice Call
                NSLog(@"同一个回话进来，从video转voice Call");
            }
            else
            {
                //从voice转video Call
                NSLog(@"同一个回话进来，从voice转video Call");
                
            }
//            self.callUpdate.hasVideo = isVideoCall;
//            [_provider reportCallWithUUID:_currentUUID updated:self.callUpdate];

        }
    }
    else
    {
        //不同的回话
        if (self.currentPhoneNumber) {
            //已有正在进行中通话  busy
            if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
                [self.delegate refreshCurrentCallStatus:CallStatus_Busy];
            }
            NSLog(@"通话正忙！");
            return;
        }
        //创建新会话
        self.currentUUID = [NSUUID UUID];
        self.currentIsVideo = isVideoCall;
        self.currentPhoneNumber = person.personHandle.value;
        
        CXHandle *handle = [[CXHandle alloc] initWithType:(CXHandleType)person.personHandle.type value:self.currentPhoneNumber];
        CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:self.currentUUID handle:handle];
        startCallAction.video = isVideoCall;
        CXTransaction *transaction = [[CXTransaction alloc] init];
        [transaction addAction:startCallAction];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [self requestTransaction:transaction];
        
        self.callUpdate.localizedCallerName = @"测试"; //根据phoneNumber 查找当前对应的name 并更新
        [_provider reportCallWithUUID:_currentUUID updated:self.callUpdate];

    }
}

#pragma mark - Event
- (void)muteCurrentCall:(BOOL)isMute
{
    CXSetMutedCallAction *muteCallAction = [[CXSetMutedCallAction alloc] initWithCallUUID:self.currentUUID muted:isMute];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:muteCallAction];
    [self requestTransaction:transaction];
}

- (void)heldCurrentCall:(BOOL)onHold
{
    CXSetHeldCallAction *heldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:self.currentUUID onHold:onHold];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:heldCallAction];
    [self requestTransaction:transaction];
}

- (void)playDTMFCurrentCall:(CXPlayDTMFCallActionType)playType andDigits:(NSString *)digits
{
    CXPlayDTMFCallAction *playDTMFCallAction = [[CXPlayDTMFCallAction alloc] initWithCallUUID:self.currentUUID digits:digits type:playType];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:playDTMFCallAction];
    [self requestTransaction:transaction];
}

- (void)setGroupCurrentCallWithGroupUUID:(NSUUID *)groupUUID
{
    CXSetGroupCallAction *groupCallAction = [[CXSetGroupCallAction alloc] initWithCallUUID:self.currentUUID callUUIDToGroupWith:groupUUID];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:groupCallAction];
    [self requestTransaction:transaction];
}

//拨打方 结束通话调用
- (void)endCallAction
{
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:self.currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] init];
    [transaction addAction:endCallAction];
    
    __weak __typeof(self) wself = self;
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error){
        if (error !=nil) {
            NSLog(@"Error requesting transaction: %@", error);
            // do something
        }
        else
        {
            NSLog(@"Requested transaction successfully");
            [wself resetVariableData];
            if (wself.delegate && [wself.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
                [wself.delegate refreshCurrentCallStatus:CallStatus_CallerEnd];
            }
        }
    }];


}


//开始连接
- (void)startedConnectingOutgoingCall
{
    [_provider reportOutgoingCallWithUUID:_currentUUID startedConnectingAtDate:nil];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_StartConnect];
    }
}

//通话连接成功 显示通话时间 作为拨打方
- (void)connectedOutgoingCall
{
    [_provider reportOutgoingCallWithUUID:_currentUUID connectedAtDate:nil];
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_Connected];
    }

}

//接听方结束电话
- (void)finshCallWithReason:(CXCallEndedReason)reason;
{
    [_provider reportCallWithUUID:self.currentUUID endedAtDate:nil reason:reason];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_AnswerEnd];
    }
}

#pragma mark - CXProviderDelegate
- (void)providerDidReset:(CXProvider *)provider
{
    NSLog(@"resetedUUID:%ld",provider.pendingTransactions.count);
}

- (void)providerDidBegin:(CXProvider *)provider
{
    // provider 创建成功
    NSLog(@"a provider begin");
}


- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction
{
    //返回true 不执行系统通话界面 直接End
    return false;
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action
{
    //通话开始
    NSLog(@"CallKit--callController--通话开始");
    //connect --- code 调起app内的呼叫界面
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_ReadyStart];
    }
    
    // logic code
    //for test
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startedConnectingOutgoingCall];

    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self connectedOutgoingCall];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self endCallAction];
    });
    
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    //接听
    NSLog(@"CallKit--provider--接听");
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_Accept];
    }
    
    //for test
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self finshCallWithReason:CXCallEndedReasonAnsweredElsewhere];
//    });
    [action fulfill];
}

//拨打方挂断或被叫方拒绝接听
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action
{
    //结束通话
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_End];
    }
    [self resetVariableData];//通话结束

    [action fulfill]; //通话结束立即执行 时间也可以选
    NSLog(@"CallKit----通话未开始就结束");
    
}
- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action
{
    //保留
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallHoldState:)]) {
        [self.delegate refreshCurrentCallHoldState:action.onHold];
    }
    [action fulfill];
    NSLog(@"CallKit----%@",(action.onHold)?@"通话保留":(@"恢复通话"));
}
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action
{
    //静音
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallMuteState:)]) {
        [self.delegate refreshCurrentCallMuteState:action.muted];
    }
    [action fulfill];
    NSLog(@"CallKit---- %@",action.muted?@"通话静音":@"通话取消静音");
}
- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action
{
    //群组电话
    NSLog(@"CallKit----群组通话");
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallGroupState:)]) {
        [self.delegate refreshCurrentCallGroupState:action.callUUIDToGroupWith];
    }
    [action fulfill];
}


- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action
{
    //双音频功能
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallplayDTMFState:andCXPlayDTMFCallActionType:)]) {
        [self.delegate refreshCurrentCallplayDTMFState:action.digits andCXPlayDTMFCallActionType:action.type];
    }
    [action fulfill];
    NSLog(@"CallKit----双音频功能");
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action
{
    //超时
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshCurrentCallStatus:)]) {
        [self.delegate refreshCurrentCallStatus:CallStatus_TimeOut];
    }
    [self resetVariableData];
    [action fulfill];
    NSLog(@"CallKit----连接超时");
}

/// Called when the provider's audio session activation state changes.
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession
{
    //audio session 设置
    NSLog(@"CallKit----audioSession changed");
    
}
- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession
{
    //call end
    NSLog(@"CallKit----didDeactivateAudioSession");
}

#pragma mark - mainPrivate
//无论何种操作都需要 话务控制器 去 提交请求 给系统
-(void)requestTransaction:(CXTransaction *)transaction
{
    [_callController requestTransaction:transaction completion:^( NSError *_Nullable error){
        if (error !=nil) {
            NSLog(@"Error requesting transaction: %@", error);
        }
        else
        {
            NSLog(@"Requested transaction successfully");
        }
    }];
}

//重置变量
- (void)resetVariableData
{
    if (self.currentPhoneNumber) {
        self.currentPhoneNumber = nil;
    }
    if (self.currentUUID) {
        self.currentUUID = nil;
    }
    self.currentIsVideo = false;
}


#pragma mark - CXCallObserverDelegate

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call
{
    NSLog(@"CallKit--callChanged--callObserver:::%ld----call.isOnHold---:::%d--call.isOutgoing--:::%d--call.hasConnected--:::%d---call.hasEnded--:::%d",callObserver.calls.count,call.isOnHold,call.isOutgoing,call.hasConnected,call.hasEnded);
    
    if (self.currentUUID)
    {
        if (callObserver.calls.count > 1) {
            self.hasOtherCall = true;
        }
        else
        {
            self.hasOtherCall = false;
        }
        if ([call.UUID.UUIDString isEqualToString:self.currentUUID.UUIDString]) {
            //当前通话
            if (call.hasEnded) {
                // 通话结束
                NSLog(@"通话结束");
            }
            
            if (call.isOutgoing) {
                NSLog(@"正在呼出会话");
            }
            
            if (call.isOnHold) {
                NSLog(@" isOnHold");
            }

        }
        
    }
    else
    {
        if (callObserver.calls.count > 0) {
            self.hasOtherCall = true;
        }
        else
        {
            self.hasOtherCall = false;
        }
    }

}

#pragma mark - setter
- (CXProviderConfiguration *)configuration
{
    if (!_configuration) {
//        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        _configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"test"];//一般是app名字
        _configuration.supportedHandleTypes = [[NSSet alloc] initWithObjects:@(CXHandleTypePhoneNumber), nil]; //不加这一行 系统电话号码长按不会出现当前app的名字（坑） 也可以支持邮件 根据app的功能来选
        NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"callkitIcon" ofType:@"png"];
        _configuration.iconTemplateImageData = [NSData dataWithContentsOfFile:iconPath];//锁屏图标 40*40 px
        NSString *ringPath = [[NSBundle mainBundle] pathForResource:@"ringtone" ofType:@"mp3"];
        _configuration.ringtoneSound = ringPath; //这是个亮点 打电话的app可以做到自定义来电铃声
        _configuration.maximumCallGroups = 0;
        _configuration.supportsVideo = YES;
    }
    return _configuration;
}

- (CXCallUpdate *)callUpdate
{
    if (!_callUpdate) {
        _callUpdate = [CXCallUpdate new];
//        _callUpdate.supportsGrouping = false;
//        _callUpdate.supportsUngrouping = true;
        _callUpdate.supportsHolding = true; //默认不同时支持其他来电
    }
    return _callUpdate;
}

- (CXCallController *)callController
{
    if (!_callController) {
        _callController = [[CXCallController alloc] init];
    }
    return _callController;
}
@end
