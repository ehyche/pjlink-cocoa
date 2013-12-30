//
//  PJRequestInfo.h
//  PJController
//
//  Created by Eric Hyche on 12/9/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PJDefinitions.h"

@interface PJRequestInfo : NSObject

@property(nonatomic,assign) NSInteger pjlinkClass;
@property(nonatomic,assign) PJCommand command;
@property(nonatomic,assign) BOOL      isSetCommand;
@property(nonatomic,copy)   NSString* encryptedPassword;

-(NSData*)   data;
-(NSString*) stringForSetData;
-(void)      parseURLQueryValue:(NSString*) queryValue;
+(NSString*) pjlink4ccForCommand:(PJCommand) command;
+(PJCommand) pjlinkCommandFor4cc:(NSString*) fourCC;

+(PJRequestInfo*) requestInfoFromURLQueryName:(NSString*) name queryValue:(NSString*) value;

+ (NSString*)queryStringForCommand:(PJCommand)cmd;
+ (NSString*)queryStringForCommands:(NSArray*)cmds;

@end

@interface PJRequestInfoPower : PJRequestInfo

@property(nonatomic,assign) BOOL powerOn;

@end

@interface PJRequestInfoInput : PJRequestInfo

@property(nonatomic,assign) PJInputType inputType;
@property(nonatomic,assign) uint8_t     inputNumber;

@end

@interface PJRequestInfoMute : PJRequestInfo

@property(nonatomic,assign) PJMuteType muteType;
@property(nonatomic,assign) BOOL       muteOn;

@end
