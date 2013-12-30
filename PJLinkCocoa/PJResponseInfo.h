//
//  PJResponseInfo.h
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PJDefinitions.h"

@class PJRequestInfo;
@class PJInputInfo;

@interface PJResponseInfo : NSObject

@property(nonatomic,assign) PJCommand command;
@property(nonatomic,assign) PJError   error;

-(BOOL)            parseResponseData:(NSString*) dataStr;
+(PJResponseInfo*) infoForResponseStringWithoutHeaderClassTerminator:(NSString*) responseStr;
+(PJResponseInfo*) infoForResponseString:(NSString*) responseStr;
+(PJResponseInfo*) infoForCommand:(PJCommand) command responseValue:(NSString*) responseStr;
+(NSString*)       pjlink4ccForCommand:(PJCommand) command;
+(PJCommand)       pjlinkCommandFor4cc:(NSString*) fourCC;

+(BOOL) scanInteger:(NSInteger*) pScanInt fromRange:(NSRange) range inString:(NSString*) str;
+(BOOL) scanInteger:(NSInteger*) pScanInt fromString:(NSString*) str;

@end

@interface PJResponseInfoPowerStatusQuery : PJResponseInfo

@property(nonatomic,assign) PJPowerStatus powerStatus;

+ (NSString*)stringForPowerStatus:(PJPowerStatus)status;

@end

@interface PJResponseInfoInputSwitchQuery : PJResponseInfo

@property(nonatomic,copy) PJInputInfo* input;

@end

@interface PJResponseInfoMuteStatusQuery : PJResponseInfo

@property(nonatomic,assign) NSInteger muteType;
@property(nonatomic,assign) BOOL      muteOn;

@end

@interface PJResponseInfoErrorStatusQuery : PJResponseInfo

@property(nonatomic,assign) PJErrorStatus fanError;
@property(nonatomic,assign) PJErrorStatus lampError;
@property(nonatomic,assign) PJErrorStatus temperatureError;
@property(nonatomic,assign) PJErrorStatus coverOpenError;
@property(nonatomic,assign) PJErrorStatus filterError;
@property(nonatomic,assign) PJErrorStatus otherError;

+ (NSString*)stringForErrorStatus:(PJErrorStatus)status;

@end

@interface PJResponseInfoLampQuery : PJResponseInfo

@property(nonatomic,copy) NSArray* lampStatuses; // Array of PJLampStatus objects

@end

@interface PJResponseInfoInputTogglingListQuery : PJResponseInfo

@property(nonatomic,copy) NSArray* inputs; // Array of PJInputInfo objects

@end

@interface  PJResponseInfoProjectorNameQuery : PJResponseInfo

@property(nonatomic,copy) NSString* projectorName;

@end

@interface PJResponseInfoManufacturerNameQuery : PJResponseInfo

@property(nonatomic,copy) NSString* manufacturerName;

@end

@interface PJResponseInfoProductNameQuery : PJResponseInfo

@property(nonatomic,copy) NSString* productName;

@end

@interface PJResponseInfoOtherInfoQuery : PJResponseInfo

@property(nonatomic,copy) NSString* otherInfo;

@end

@interface PJResponseInfoClassInfoQuery : PJResponseInfo

@property(nonatomic,assign) BOOL class2Compatible;

@end
