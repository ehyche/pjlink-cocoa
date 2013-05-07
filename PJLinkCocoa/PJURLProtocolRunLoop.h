//
//  PJURLProtocolRunLoop.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/25/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* const kPJLinkScheme;
NSString* const kPJLinkPOWR;
NSString* const kPJLinkINPT;
NSString* const kPJLinkAVMT;
NSString* const kPJLinkERST;
NSString* const kPJLinkLAMP;
NSString* const kPJLinkINST;
NSString* const kPJLinkNAME;
NSString* const kPJLinkINF1;
NSString* const kPJLinkINF2;
NSString* const kPJLinkINFO;
NSString* const kPJLinkCLSS;
NSString* const kPJLinkOK;
NSString* const kPJLinkERR1;
NSString* const kPJLinkERR2;
NSString* const kPJLinkERR3;
NSString* const kPJLinkERR4;
NSString* const kPJLinkHeaderClass;
NSString* const PJLinkErrorDomain;
NSString* const kPJLinkCR;

enum {
    PJLinkErrorUnknown                  = -1,
    PJLinkErrorNoValidCommandsInRequest = -100,
    PJLinkErrorInvalidAuthSeed          = -101,
    PJLinkErrorNoDataInAuthChallenge    = -102,
    PJLinkErrorNoPasswordProvided       = -103,
    PJLinkErrorNoDataInResponse         = -104,
    PJLinkErrorMissingResponseHeader    = -105
};

@interface PJURLProtocolRunLoop : NSURLProtocol

@end
