//
//  PJResponseInfo.m
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "PJResponseInfo.h"
#import "PJRequestInfo.h"
#import "PJDefinitions.h"

#define k_headerClass @"%1"

static NSArray*      gCommandToResponseClassMap = nil;
static NSDictionary* gErrorStringToPJErrorMap   = nil;

@implementation PJResponseInfo

@synthesize command;
@synthesize isSetCommand;
@synthesize error;

+(void) initialize
{
    if (self == [PJResponseInfo class])
    {
        gCommandToResponseClassMap =
        @[
            [PJResponseInfoPowerStatusQuery class],       // PJCommandPower
            [PJResponseInfoInputSwitchQuery class],       // PJCommandInput
            [PJResponseInfoMuteStatusQuery class],        // PJCommandAVMute
            [PJResponseInfoErrorStatusQuery class],       // PJCommandErrorQuery
            [PJResponseInfoLampQuery class],              // PJCommandLampQuery
            [PJResponseInfoInputTogglingListQuery class], // PJCommandInputListQuery
            [PJResponseInfoProjectorNameQuery class],     // PJCommandProjectorNameQuery
            [PJResponseInfoManufacturerNameQuery class],  // PJCommandManufacturerNameQuery
            [PJResponseInfoProductNameQuery class],       // PJCommandProductNameQuery
            [PJResponseInfoOtherInfoQuery class],         // PJCommandOtherInfoQuery
            [PJResponseInfoClassInfoQuery class]          // PJCommandClassInfoQuery
        ];
        gErrorStringToPJErrorMap =
        @{
            @"OK"   : @(PJErrorOK),
            @"ERR1" : @(PJErrorUndefinedCommand),
            @"ERR2" : @(PJErrorBadParameter),
            @"ERR3" : @(PJErrorCommandUnavailable),
            @"ERR4" : @(PJErrorProjectorFailure)
        };
    }
}

-(BOOL) parseResponseData:(NSString*) dataStr
{
    BOOL bRet = NO;

    // Check to see if the response string
    NSNumber* pjErrorNum = [gErrorStringToPJErrorMap objectForKey:dataStr];
    if (pjErrorNum != nil)
    {
        // This response string maps to a particular PJError
        PJError pjError = [pjErrorNum integerValue];
        // Set the value
        self.error = pjError;
        // Set the return value to say we parsed it
        bRet = YES;
    }

    return bRet;
}

+(PJResponseInfo*) infoForResponseData:(NSData*) data fromRequest:(PJRequestInfo*) request
{
    PJResponseInfo* ret = nil;

    // Get the string from the data
    NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // The format of the response is:
    //
    // %1XXXX=<data><CR>
    //
    // where:
    //
    // XXXX - is the four-character command code
    // <data> is the variable-length data
    // <CR>   is a carrage return
    //
    // So to be valid, we have to at least have:
    // %1     2 characters
    // XXXX   4 characters
    // =      1 character
    // <CR>   1 character
    // <data> >= 1 character
    //
    // So our response must be >= 9 characters
    NSUInteger dataStrLen = [dataStr length];
    if (dataStrLen >= 9)
    {
        // Get the first two characters
        NSString* headerClassStr = [dataStr substringToIndex:2];
        // This better be "%1"
        if ([headerClassStr isEqualToString:k_headerClass])
        {
            // Get the command (characters 2-5) string
            NSString* commandStr = [dataStr substringWithRange:NSMakeRange(2, 4)];
            // Look up the command from the string
            PJCommand command = [PJRequestInfo pjlinkCommandFor4cc:commandStr];
            if (command < PJCommandUnknown)
            {
                // Make sure character 6 is an "="
                NSString* char6Str = [dataStr substringWithRange:NSMakeRange(6, 1)];
                if ([char6Str isEqualToString:@"="])
                {
                    // Get the last character
                    NSString* lastCharStr = [dataStr substringWithRange:NSMakeRange(dataStrLen-1, 1)];
                    // Make sure this is the PJ terminator
                    if ([lastCharStr isEqualToString:@"\n"])
                    {
                        // Get the data between the "=" and the carriage return at the end
                        NSString* responseDataStr = [dataStr substringWithRange:NSMakeRange(7, dataStrLen - 8)];
                        // Create the appropriate PJResponseInfo object
                        PJResponseInfo* responseInfo = [PJResponseInfo infoForCommand:command isSet:request.isSetCommand];
                        // Set the .command and .isSetCommand parameters
                        responseInfo.command      = command;
                        responseInfo.isSetCommand = request.isSetCommand;
                        // Parse the response data
                        BOOL bSuccess = [responseInfo parseResponseData:responseDataStr];
                        if (bSuccess)
                        {
                            ret = responseInfo;
                        }
                        else
                        {
                            NSLog(@"Could not parse response data string (\"%@\") for request %@", dataStr, request);
                        }
                    }
                    else
                    {
                        NSLog(@"PJResponseInfo: last character is not a carriage return");
                    }
                }
                else
                {
                    NSLog(@"PJResponseInfo: character 6 in response is not equals sign");
                }
            }
            else
            {
                NSLog(@"PJResponseInfo: Unknown command %@", commandStr);
            }
        }
        else
        {
            NSLog(@"PJResponseInfo: first two characters are not %%1");
        }
    }
    else
    {
        NSLog(@"PJResponseInfo: response is too short.");
    }

    return ret;
}

+(PJResponseInfo*) infoForCommand:(PJCommand) command isSet:(BOOL) isSet
{
    PJResponseInfo* ret = nil;

    // Get the number of classes in the static array
    NSUInteger numClasses = [gCommandToResponseClassMap count];
    if (command < numClasses)
    {
        if (isSet)
        {
            // All set commands just have the basic response data
            ret = [[PJResponseInfo alloc] init];
        }
        else
        {
            // Look up the PJResponseInfo class from the array
            Class responseInfoClass = [gCommandToResponseClassMap objectAtIndex:command];
            // Create the response info object
            ret = [[responseInfoClass alloc] init];
        }
    }

    return ret;
}

+(BOOL) scanInteger:(NSInteger*) pScanInt fromRange:(NSRange) range inString:(NSString*) str
{
    BOOL bRet = NO;

    // Get the string length
    NSUInteger strLen = [str length];
    // Make sure this is a valid parsing request
    if (pScanInt != NULL && strLen > 0 && range.length > 0 &&
        range.location + range.length <= strLen)
    {
        // Create the substring with this range
        NSString* subStr = [str substringWithRange:range];
        // Create a scanner with this range
        NSScanner* scanner = [NSScanner scannerWithString:subStr];
        // Attempt to scan an integer
        bRet = [scanner scanInteger:pScanInt];
    }

    return bRet;
}

+(BOOL) scanInteger:(NSInteger*) pScanInt fromString:(NSString*) str
{
    BOOL bRet = NO;
    
    // Get the string length
    NSUInteger strLen = [str length];
    // Make sure this is a valid parsing request
    if (pScanInt != NULL && strLen > 0)
    {
        // Create a scanner with this range
        NSScanner* scanner = [NSScanner scannerWithString:str];
        // Attempt to scan an integer
        bRet = [scanner scanInteger:pScanInt];
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoPowerStatusQuery

@synthesize powerStatus;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // The length better be 1
        if ([dataStr length] == 1)
        {
            // Parse the power status integer
            NSInteger powerStatusInt = 0;
            BOOL bScanRet = [PJResponseInfo scanInteger:&powerStatusInt fromRange:NSMakeRange(0, 1) inString:dataStr];
            if (bScanRet)
            {
                // Make sure this is legal power status value
                if (powerStatusInt < NumPJPowerStatuses)
                {
                    // Set the power status
                    self.powerStatus = powerStatusInt;
                    // Set the flag saying we parsed successfully
                    bRet = YES;
                }
            }
        }
    }
    
    return bRet;
}

@end

@implementation PJInput

@synthesize inputType;
@synthesize inputNumber;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    BOOL bRet = NO;

    if ([dataStr length] == 2)
    {
        // Scan the input type
        NSInteger inputTypeInt = 0;
        BOOL bScanRet = [PJResponseInfo scanInteger:&inputTypeInt fromRange:NSMakeRange(0, 1) inString:dataStr];
        if (bScanRet)
        {
            // Scan the input number
            NSInteger inputNumberInt = 0;
            bScanRet = [PJResponseInfo scanInteger:&inputNumberInt fromRange:NSMakeRange(1, 1) inString:dataStr];
            if (bScanRet)
            {
                // Check validity of these scanned integers
                if (inputTypeInt >= PJInputTypeRGB && inputTypeInt <= PJInputTypeNetwork &&
                    inputNumberInt >= 1 && inputNumberInt <= 9)
                {
                    self.inputType   = inputTypeInt;
                    self.inputNumber = (uint8_t) inputNumberInt;
                    // Set the flag saying we parsed successfully
                    bRet = YES;
                }
            }
        }
    }

    return bRet;
}


@end

@implementation PJResponseInfoInputSwitchQuery

@synthesize input;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Create a PJInput
        PJInput* tmp = [[PJInput alloc] init];
        bRet = [tmp parseResponseData:dataStr];
        if (bRet)
        {
            self.input = tmp;
            bRet = YES;
        }
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoMuteStatusQuery

@synthesize muteType;
@synthesize muteOn;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Scan the mute type
        NSInteger muteTypeInt = 0;
        BOOL bScanRet = [PJResponseInfo scanInteger:&muteTypeInt fromRange:NSMakeRange(0, 1) inString:dataStr];
        if (bScanRet)
        {
            // Scan the mute status
            NSInteger muteStatusInt = 0;
            bScanRet = [PJResponseInfo scanInteger:&muteStatusInt fromRange:NSMakeRange(1, 1) inString:dataStr];
            if (bScanRet)
            {
                // Check validity of these scanned integers
                if (muteTypeInt >= 1 && muteTypeInt <= 3 &&
                    muteStatusInt >= 0 && muteStatusInt <= 1)
                {
                    // Set the mute type and status
                    self.muteType = muteTypeInt;
                    self.muteOn   = (muteStatusInt ? YES : NO);
                    // Set the flag saying we parsed successfully
                    bRet = YES;
                }
            }
        }
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoErrorStatusQuery

@synthesize fanError;
@synthesize lampError;
@synthesize temperatureError;
@synthesize coverOpenError;
@synthesize filterError;
@synthesize otherError;

-(BOOL) scanError:(PJErrorStatus*) pError fromRange:(NSRange) range inString:(NSString*) dataStr
{
    BOOL bRet = NO;

    if (pError != NULL)
    {
        NSInteger errorInt = 0;
        BOOL scanRet = [PJResponseInfo scanInteger:&errorInt fromRange:range inString:dataStr];
        if (scanRet)
        {
            // Check validity of error
            if (errorInt >= 0 && errorInt < NumPJErrorStatuses)
            {
                *pError = errorInt;
                bRet    = YES;
            }
        }
    }

    return bRet;
}

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        PJErrorStatus fanErr;
        BOOL bScanRet = [self scanError:&fanErr fromRange:NSMakeRange(0, 1) inString:dataStr];
        if (bScanRet)
        {
            PJErrorStatus lampErr;
            bScanRet = [self scanError:&lampErr fromRange:NSMakeRange(1, 1) inString:dataStr];
            if (bScanRet)
            {
                PJErrorStatus tempErr;
                bScanRet = [self scanError:&tempErr fromRange:NSMakeRange(2, 1) inString:dataStr];
                if (bScanRet)
                {
                    PJErrorStatus coverErr;
                    bScanRet = [self scanError:&coverErr fromRange:NSMakeRange(3, 1) inString:dataStr];
                    if (bScanRet)
                    {
                        PJErrorStatus filterErr;
                        bScanRet = [self scanError:&filterErr fromRange:NSMakeRange(4, 1) inString:dataStr];
                        if (bScanRet)
                        {
                            PJErrorStatus otherErr;
                            bScanRet = [self scanError:&otherErr fromRange:NSMakeRange(5, 1) inString:dataStr];
                            if (bScanRet)
                            {
                                // Assign the errors
                                self.fanError         = fanErr;
                                self.lampError        = lampErr;
                                self.temperatureError = tempErr;
                                self.coverOpenError   = coverErr;
                                self.filterError      = filterErr;
                                self.otherError       = otherErr;
                                // Set the flag saying we parsed successfully
                                bRet = YES;
                            }
                        }
                    }
                }
            }
        }
    }
    
    return bRet;
}

@end

@implementation PJLampStatus

@synthesize cumulativeLightingTime;
@synthesize lampOn;

@end

@implementation PJResponseInfoLampQuery

@synthesize lampStatuses;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Split the string by the space delimiter
        NSArray* dataComponents = [dataStr componentsSeparatedByString:@" "];
        // Get the number of components
        NSUInteger numDataComponents = [dataComponents count];
        // This better be an even number
        if ((numDataComponents & 1) == 0)
        {
            // Get the number of PJLampStatus's
            NSUInteger numLampStatuses = numDataComponents / 2;
            // Create the temporary array of PJLampStatus's
            NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:numLampStatuses];
            for (NSUInteger i = 0; i < numLampStatuses; i++)
            {
                // Compute the component indices
                NSUInteger lightingTimeIndex = i * 2;
                NSUInteger lampStatusIndex   = lightingTimeIndex + 1;
                // Get the components for these indices
                NSString* lightingTimeDataStr = [dataComponents objectAtIndex:lightingTimeIndex];
                NSString* lampStatusDataStr   = [dataComponents objectAtIndex:lampStatusIndex];
                // Parse the lighting time for the i-th lamp
                NSInteger lightingTime = 0;
                BOOL bScanRet = [PJResponseInfo scanInteger:&lightingTime fromString:lightingTimeDataStr];
                if (bScanRet)
                {
                    // Parse the lamp status for the i-th lamp
                    NSInteger lampStatusInt = 0;
                    bScanRet = [PJResponseInfo scanInteger:&lampStatusInt fromString:lampStatusDataStr];
                    if (bScanRet)
                    {
                        // Check validity
                        if (lightingTime >= 0 && (lampStatusInt == 0 || lampStatusInt == 1))
                        {
                            // Create the PJLampStatus
                            PJLampStatus* lampStatus = [[PJLampStatus alloc] init];
                            // Set the cumulativeLightingTime and lampOn properties
                            lampStatus.cumulativeLightingTime = lightingTime;
                            lampStatus.lampOn                 = (lampStatusInt ? YES : NO);
                            // Add this to the temporary array
                            [tmp addObject:lampStatus];
                        }
                    }
                }
            }
            if ([tmp count] > 0)
            {
                // Copy the array
                self.lampStatuses = tmp;
                // Set the flag saying we parsed successfully
                bRet = YES;
            }
        }
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoInputTogglingListQuery

@synthesize inputs;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Split the string by the space delimiter
        NSArray* dataComponents = [dataStr componentsSeparatedByString:@" "];
        // Get the number of components
        NSUInteger numDataComponents = [dataComponents count];
        // Create a temporary array
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:numDataComponents];
        // Iterate through the components
        for (NSString* dataComponent in dataComponents)
        {
            // Create a PJInput
            PJInput* tmpInput = [[PJInput alloc] init];
            // Parse the input
            BOOL bParse = [tmpInput parseResponseData:dataComponent];
            if (bParse)
            {
                // Add it to the output array
                [tmp addObject:tmpInput];
            }
        }
        if ([tmp count] > 0)
        {
            // Copy the array of PJInput's
            self.inputs = tmp;
            // Set the flag saying we parsed successfully
            bRet = YES;
        }
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoProjectorNameQuery

@synthesize projectorName;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Copy the projector name
        self.projectorName = dataStr;
        // Set the flag saying we parsed successfully
        bRet = YES;
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoManufacturerNameQuery

@synthesize manufacturerName;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Copy the manufacturer name
        self.manufacturerName = dataStr;
        // Set the flag saying we parsed successfully
        bRet = YES;
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoProductNameQuery

@synthesize productName;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Copy the product name
        self.productName = dataStr;
        // Set the flag saying we parsed successfully
        bRet = YES;
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoOtherInfoQuery

@synthesize otherInfo;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // Copy the other information
        self.otherInfo = dataStr;
        // Set the flag saying we parsed successfully
        bRet = YES;
    }
    
    return bRet;
}

@end

@implementation PJResponseInfoClassInfoQuery

@synthesize class2Compatible;

-(BOOL) parseResponseData:(NSString*) dataStr
{
    // See if the response is one of the errors
    BOOL bRet = [super parseResponseData:dataStr];
    if (!bRet)
    {
        // If this is a Class-2 compatible projector, then this string is "2"
        self.class2Compatible = [dataStr isEqualToString:@"2"];
        // Set the flag saying we parsed successfully
        bRet = YES;
    }
    
    return bRet;
}

@end

