//
//  PJLampStatus.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJLampStatus.h"

@implementation PJLampStatus

+ (PJLampStatus*)lampStatusWithOn:(BOOL)on cumulativeLightingTime:(NSUInteger)time {
    PJLampStatus* ret = [[PJLampStatus alloc] init];
    ret.lampOn = on;
    ret.cumulativeLightingTime = time;
    return ret;
}

- (BOOL)isEqual:(id)object {
    BOOL ret = NO;

    if ([object isKindOfClass:[PJLampStatus class]]) {
        PJLampStatus* lampStatus = (PJLampStatus*)object;
        if (lampStatus.lampOn                 == self.lampOn &&
            lampStatus.cumulativeLightingTime == self.cumulativeLightingTime) {
            ret = YES;
        }
    }

    return ret;
}

@end
