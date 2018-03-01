//
//  UIApplication+TG_IdleTimer.m
//  TradeBook
//
//  Created by tsaievan on 1/3/18.
//  Copyright © 2018年 tsaievan. All rights reserved.
//

#import "UIApplication+TG_IdleTimer.h"
#import <objc/message.h>

const char *TG_IDLE_TIMER_KEY = "TG_IDLE_TIMER_KEY";
const NSInteger APPLICATION_DEFAULT_IDLE_TIME = 1;
const char *UIAPPLICATION_CLASS = "UIApplication";
static NSString *const TG_APPLICATION_TIMEOUT_NOTIFICATION = @"TG_APPLICATION_TIMEOUT_NOTIFICATION";

@implementation UIApplication (TG_IdleTimer)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [objc_getClass(UIAPPLICATION_CLASS) tg_getOrigMenthod:@selector(sendEvent:) swizzledMethod:@selector(_tg_sendEvent:)];
    });
}

+ (BOOL)tg_getOrigMenthod:(SEL)orignalSel swizzledMethod:(SEL)swizzledSel {
    ///< 得到原方法和交换方法
    Method originalMethod = class_getInstanceMethod([self class], swizzledSel);
    Method swizzledMethod = class_getInstanceMethod([self class], orignalSel);
    
    ///< 如果有一个方法获取不到, 直接return
    if (!originalMethod || !swizzledMethod) {
        return NO;
    }
    
    ///< 方法是否能加入到方法列表中
    BOOL didAddMethod = class_addMethod([self class], orignalSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) { ///< 如果加入成功, 用新方法代替旧方法
        class_replaceMethod([self class], swizzledSel, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    }else { ///< 如果加入不成功, 交换方法
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    return YES;
}

- (void)_tg_sendEvent:(UIEvent *)event {
    [self _tg_sendEvent:event]; ///< 相当于调用系统的方法
    NSTimer *idleTimer = objc_getAssociatedObject(self, TG_IDLE_TIMER_KEY);
    if (!idleTimer) {
        [self _tg_resetIdleTimer];
    }
    NSSet *allTouches = [event allTouches];
    if (allTouches.count > 0) {
        UITouchPhase phase = ((UITouch *)allTouches.anyObject).phase;
        if (phase == UITouchPhaseBegan) {
            [self _tg_resetIdleTimer];
        }
    }
}

- (void)_tg_resetIdleTimer {
    NSTimer *idleTimer = objc_getAssociatedObject(self, TG_IDLE_TIMER_KEY);
    if (idleTimer) {
        [idleTimer invalidate];
    }
    NSTimeInterval timeout = APPLICATION_DEFAULT_IDLE_TIME * 60;
    idleTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(_tg_idleTimerExceed) userInfo:nil repeats:NO];
    objc_setAssociatedObject(self, TG_IDLE_TIMER_KEY, idleTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_tg_idleTimerExceed {
    [[NSNotificationCenter defaultCenter] postNotificationName:TG_APPLICATION_TIMEOUT_NOTIFICATION object:nil];
}

@end
