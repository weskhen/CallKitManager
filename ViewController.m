//
//  ViewController.m
//  callkitManager
//
//  Created by wujian on 10/31/16.
//  Copyright © 2016 wesk痕. All rights reserved.
//

#import "ViewController.h"
#import "AppCallKitManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AppCallKitManager sharedInstance] showCallInComingWithName:@"测试wesk痕" andPhoneNumber:@"+8613088888888" isVideoCall:false];
        NSLog(@"call coming");
    });

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
