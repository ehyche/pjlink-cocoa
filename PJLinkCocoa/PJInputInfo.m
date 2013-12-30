//
//  PJInputInfo.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJInputInfo.h"
#import "PJResponseInfo.h"

static NSArray* gInputTypeNames = nil;

@implementation PJInputInfo

+(void) initialize {
    if (self == [PJInputInfo class]) {
        gInputTypeNames = @[@"Invalid", @"RGB", @"Video", @"Digital", @"Storage", @"Network"];
    }
}

+ (PJInputInfo*)inputInfoWithType:(PJInputType)type number:(NSUInteger)number {
    PJInputInfo* ret = [[PJInputInfo alloc] init];
    ret.inputType = type;
    ret.inputNumber = number;
    return ret;
}

+ (NSString*)nameForInputType:(PJInputType)type {
    NSString* ret = nil;

    if (type < [gInputTypeNames count]) {
        ret = [gInputTypeNames objectAtIndex:type];
    }

    return ret;
}

- (id)copyWithZone:(NSZone*)zone {
    PJInputInfo* inputCopy = [[PJInputInfo alloc] init];

    inputCopy.inputType   = self.inputType;
    inputCopy.inputNumber = self.inputNumber;

    return inputCopy;
}

-(BOOL) parseResponseData:(NSString*) dataStr {
    BOOL bRet = NO;

    if ([dataStr length] == 2) {
        // Scan the input type
        NSInteger inputTypeInt = 0;
        BOOL bScanRet = [PJResponseInfo scanInteger:&inputTypeInt fromRange:NSMakeRange(0, 1) inString:dataStr];
        if (bScanRet) {
            // Scan the input number
            NSInteger inputNumberInt = 0;
            bScanRet = [PJResponseInfo scanInteger:&inputNumberInt fromRange:NSMakeRange(1, 1) inString:dataStr];
            if (bScanRet) {
                // Check validity of these scanned integers
                if (inputTypeInt >= PJInputTypeRGB && inputTypeInt <= PJInputTypeNetwork &&
                    inputNumberInt >= 1 && inputNumberInt <= 9) {
                    self.inputType   = inputTypeInt;
                    self.inputNumber = inputNumberInt;
                    // Set the flag saying we parsed successfully
                    bRet = YES;
                }
            }
        }
    }

    return bRet;
}

- (BOOL)isEqual:(id)object {
    BOOL ret = NO;

    if ([object isKindOfClass:[PJInputInfo class]]) {
        PJInputInfo* inputInfo = (PJInputInfo*)object;
        if (inputInfo.inputType   == self.inputType &&
            inputInfo.inputNumber == self.inputNumber) {
            ret = YES;
        }
    }

    return ret;
}

@end
