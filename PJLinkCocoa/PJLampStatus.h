//
//  PJLampStatus.h
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PJLampStatus : NSObject <NSCoding>

@property(nonatomic,assign) BOOL       lampOn;
@property(nonatomic,assign) NSUInteger cumulativeLightingTime;

+ (PJLampStatus*)lampStatusWithOn:(BOOL)on cumulativeLightingTime:(NSUInteger)time;

@end
