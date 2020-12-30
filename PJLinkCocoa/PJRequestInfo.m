//
//  PJRequestInfo.m
//  PJController
//
//  Created by Eric Hyche on 12/9/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "PJRequestInfo.h"
#import "PJDefinitions.h"

static NSArray*      gCommandEnumToFourCharacterCode = nil;
static NSDictionary* gFourCharacterCodeToCommandEnum = nil;

@implementation PJRequestInfo

@synthesize command;
@synthesize isSetCommand;

+(void) initialize
{
    if (self == [PJRequestInfo class])
    {
        gCommandEnumToFourCharacterCode =
        @[
            @"POWR", // PJCommandPower
            @"INPT", // PJCommandInput
            @"AVMT", // PJCommandAVMute
            @"ERST", // PJCommandErrorQuery
            @"LAMP", // PJCommandLampQuery
            @"INST", // PJCommandInputListQuery
            @"NAME", // PJCommandProjectorNameQuery
            @"INF1", // PJCommandManufacturerNameQuery
            @"INF2", // PJCommandProductNameQuery
            @"INFO", // PJCommandOtherInfoQuery
            @"CLSS"  // PJCommandClassInfoQuery
        ];
        // Now construct the reverse array
        NSUInteger           numCommandEnums = [gCommandEnumToFourCharacterCode count];
        NSMutableDictionary* tmp             = [NSMutableDictionary dictionaryWithCapacity:numCommandEnums];
        for (NSUInteger i = 0; i < numCommandEnums; i++)
        {
            NSString* fourCCStr = [gCommandEnumToFourCharacterCode objectAtIndex:i];
            [tmp setObject:[NSNumber numberWithUnsignedInteger:i] forKey:fourCCStr];
        }
        gFourCharacterCodeToCommandEnum = [NSDictionary dictionaryWithDictionary:tmp];
    }
}

-(id) init
{
    self = [super init];
    if (self)
    {
        self.pjlinkClass = 1;
    }

    return self;
}

-(NSData*) data
{
    NSMutableString* tmp = [NSMutableString string];
    // Get the encrypted password. If we have
    // a password, then it goes first in the request
    NSString* password = self.encryptedPassword;
    if (password != nil)
    {
        [tmp appendString:password];
    }
    // Add the % and the class
    [tmp appendFormat:@"%%%ld", (long)self.pjlinkClass];
    // Get the 4cc
    NSString* commandStr = [PJRequestInfo pjlink4ccForCommand:self.command];
    if ([commandStr length] > 0)
    {
        [tmp appendString:commandStr];
    }
    // Is this a get request or a set request?
    if (self.isSetCommand)
    {
        // Append the space
        [tmp appendString:@" "];
        // Get the string for the set data
        NSString* setStr = [self stringForSetData];
        if (setStr != nil)
        {
            // Append the set data
            [tmp appendString:setStr];
        }
        // Append the terminator
        [tmp appendString:@"\n"];
    }
    else
    {
        // This is a get, which is the same for all commands
        [tmp appendString:@" ?\n"];
    }

    return [tmp dataUsingEncoding:NSUTF8StringEncoding];
}

-(NSString*) stringForSetData
{
    NSLog(@"PJRequestInfo[%p] stringForSetData should NEVER be called for base class", self);
    // There is no set data for the base class
    return nil;
}

-(void) parseURLQueryValue:(NSString*) queryValue
{
    // Nothing to do in base class
}

+(NSString*) pjlink4ccForCommand:(PJCommand) command
{
    NSString* ret = nil;
    
    if (command < NumPJCommands)
    {
        ret = [gCommandEnumToFourCharacterCode objectAtIndex:command];
    }

    return ret;
}

+(PJCommand) pjlinkCommandFor4cc:(NSString*) fourCC
{
    PJCommand ret = NumPJCommands;
    
    if ([fourCC length] > 0)
    {
        // Look up the command from the dictionary
        NSNumber* commandNum = [gFourCharacterCodeToCommandEnum objectForKey:fourCC];
        if (commandNum != nil)
        {
            ret = (PJCommand) [commandNum unsignedIntegerValue];
        }
    }

    return ret;
}

+(PJRequestInfo*) requestInfoFromURLQueryName:(NSString*) name queryValue:(id) value
{
    PJRequestInfo* ret = nil;

    // Change query name to uppercase
    NSString* queryNameUppercase = [name uppercaseString];
    // Look up the command enum
    PJCommand pjCommand = [PJRequestInfo pjlinkCommandFor4cc:queryNameUppercase];
    // Determine if this is a set or get command
    BOOL isSetCommand = (value != [NSNull null] ? YES : NO);
    // Create the PJRequestInfo object
    switch (pjCommand)
    {
        case PJCommandPower:   ret = [[PJRequestInfoPower alloc] init]; break;
        case PJCommandInput:   ret = [[PJRequestInfoInput alloc] init]; break;
        case PJCommandAVMute : ret = [[PJRequestInfoMute alloc] init]; break;
        default:               ret = [[PJRequestInfo alloc] init]; break;
    }
    // Set the command
    ret.command = pjCommand;
    // Set the flag saying whether it is a set command or not
    ret.isSetCommand = isSetCommand;
    // If it IS a set command, then parse the value
    if (isSetCommand)
    {
        [ret parseURLQueryValue:value];
    }

    return ret;
}

+ (NSString*)queryStringForCommand:(PJCommand)cmd {
    NSString* ret = nil;

    if (cmd < NumPJCommands) {
        ret = [NSString stringWithFormat:@"%@ ?\r", [gCommandEnumToFourCharacterCode objectAtIndex:cmd]];
    }

    return ret;
}

+ (NSString*)queryStringForCommands:(NSArray*)cmds {
    NSUInteger       cmdsCount = [cmds count];
    NSMutableString* tmp       = [NSMutableString string];

    if (cmdsCount > 0) {
        for (NSNumber* cmdNum in cmds) {
            PJCommand cmd = (PJCommand) [cmdNum integerValue];
            NSString* queryStr = [PJRequestInfo queryStringForCommand:cmd];
            if ([queryStr length] > 0) {
                [tmp appendString:queryStr];
            }
        }
    }

    return [NSString stringWithString:tmp];
}

@end

@implementation PJRequestInfoPower

@synthesize powerOn;

-(NSString*) stringForSetData
{
    return [NSString stringWithFormat:@"%u", self.powerOn];
}

-(void) parseURLQueryValue:(NSString*) queryValue
{
    // Set the powerOn from this value
    self.powerOn = [queryValue boolValue];
}


@end

@implementation PJRequestInfoInput

@synthesize inputType;
@synthesize inputNumber;

-(NSString*) stringForSetData
{
    return [NSString stringWithFormat:@"%ld%u", (long)self.inputType, self.inputNumber];
}

-(void) parseURLQueryValue:(NSString*) queryValue
{
    // This should be a two-digit value
    if ([queryValue length] == 2)
    {
        // Get the input type
        NSInteger inputTypeInt = [[queryValue substringWithRange:NSMakeRange(0, 1)] integerValue];
        // Get the input number
        NSInteger inputNumberInt = [[queryValue substringWithRange:NSMakeRange(1, 1)] integerValue];
        // Set the inputType
        if (inputTypeInt >= PJInputTypeRGB && inputTypeInt <= PJInputTypeNetwork)
        {
            self.inputType = (PJInputType) inputTypeInt;
        }
        else
        {
            // Error, default to RGB
            self.inputType = PJInputTypeRGB;
        }
        // Set the input number
        if (inputNumberInt >= 1 && inputNumberInt <= 9)
        {
            self.inputNumber = (uint8_t) inputNumberInt;
        }
        else
        {
            // Error, default to 1
            self.inputNumber = 1;
        }
    }
}

@end


@implementation PJRequestInfoMute

@synthesize muteType;
@synthesize muteOn;

-(NSString*) stringForSetData
{
    return [NSString stringWithFormat:@"%ld%u", (long)self.muteType, self.muteOn];
}

-(void) parseURLQueryValue:(NSString*) queryValue
{
    // This should be a two-digit value
    if ([queryValue length] == 2)
    {
        // Get the mute type
        NSInteger muteTypeInt = [[queryValue substringWithRange:NSMakeRange(0, 1)] integerValue];
        // Get the mute state
        BOOL muteState = [[queryValue substringWithRange:NSMakeRange(1, 1)] boolValue];
        // Set the mute type
        if (muteTypeInt >= 1 && muteTypeInt <= 3)
        {
            self.muteType = (PJMuteType) muteTypeInt;
        }
        else
        {
            // Error value, default to audio and video
            self.muteType = PJMuteTypeAudioAndVideo;
        }
        // Set the mute state
        self.muteOn = muteState;
    }
}

@end
