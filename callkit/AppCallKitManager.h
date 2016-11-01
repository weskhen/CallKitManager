//
//  AppCallKitManager.h
//  callkitManager
//
//  Created by wujian on 10/25/16.
//  Copyright © 2016 wesk痕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CallKit/CallKit.h>

typedef enum : NSUInteger {
    CallStatus_None,
    CallStatus_BuildCallerFail, //拨打方创建通话失败
    CallStatus_BuildAnswerFail,//接听方创建通话失败
    CallStatus_End,//在系统通话界面结束
    CallStatus_AnswerEnd,//接听方结束通话
    CallStatus_CallerEnd,//拨打方结束通话
    CallStatus_TimeOut,//等待超时
    CallStatus_Accept,//接听话 按下接听按钮后
    CallStatus_ReadyStart,//从系统通讯录进入的准备好 无界面展示
    CallStatus_Busy,//正在忙碌
    CallStatus_StartConnect,//开始连接
    CallStatus_Connected,//连接成功 显示时间
} CallStatus;
@protocol AppCallKitManagerDelegate <NSObject>

@required
- (void)refreshCurrentCallStatus:(CallStatus)status;

@optional

- (void)refreshCurrentCallHoldState:(BOOL)onHold;
- (void)refreshCurrentCallMuteState:(BOOL)isMute;
- (void)refreshCurrentCallplayDTMFState:(NSString *)digits andCXPlayDTMFCallActionType:(CXPlayDTMFCallActionType)playType;
- (void)refreshCurrentCallGroupState:(NSUUID*)groupUUID;

@end

@interface AppCallKitManager : NSObject

+ (AppCallKitManager*)sharedInstance;

@property (nonatomic, weak)  id<AppCallKitManagerDelegate>delegate;


/*** 接收方 展示电话呼入等待接收界面 ****/
- (void)showCallInComingWithName:(NSString *)userName andPhoneNumber:(NSString *)phoneNumber isVideoCall:(BOOL)isVideo;
/**** 拨打方 呼出电话 ****/
- (void)starCallWithUserActivity:(NSUserActivity *)userActivity;

/******* Action **********/
//拨打方 开始连接
- (void)startedConnectingOutgoingCall;
//拨打方 通话连接成功 显示通话时间
- (void)connectedOutgoingCall;
//拨打方 结束通话调用
- (void)endCallAction;

//接听方 结束电话
- (void)finshCallWithReason:(CXCallEndedReason)reason;

/****** commom *****/
//禁音通话
- (void)muteCurrentCall:(BOOL)isMute;
//保留通话
- (void)heldCurrentCall:(BOOL)onHold;
//设置双音频功能
- (void)playDTMFCurrentCall:(CXPlayDTMFCallActionType)playType andDigits:(NSString *)digits;
//设置群组通话
- (void)setGroupCurrentCallWithGroupUUID:(NSUUID *)groupUUID;


@end
