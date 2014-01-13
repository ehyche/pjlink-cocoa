//
//  PJInputInfo.h
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PJDefinitions.h"

@interface PJInputInfo : NSObject <NSCopying, NSCoding>

@property(nonatomic,assign) PJInputType inputType;
@property(nonatomic,assign) NSUInteger  inputNumber;

+ (PJInputInfo*)inputInfoWithType:(PJInputType)type number:(NSUInteger)number;

+ (NSString*)nameForInputType:(PJInputType)type;

-(BOOL) parseResponseData:(NSString*) dataStr;

@end
