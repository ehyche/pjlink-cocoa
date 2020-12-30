//
//  PJURLProtocolRunLoop.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/25/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kPJLinkScheme;
extern NSString* const kPJLinkPOWR;
extern NSString* const kPJLinkINPT;
extern NSString* const kPJLinkAVMT;
extern NSString* const kPJLinkERST;
extern NSString* const kPJLinkLAMP;
extern NSString* const kPJLinkINST;
extern NSString* const kPJLinkNAME;
extern NSString* const kPJLinkINF1;
extern NSString* const kPJLinkINF2;
extern NSString* const kPJLinkINFO;
extern NSString* const kPJLinkCLSS;
extern NSString* const kPJLinkOK;
extern NSString* const kPJLinkERR1;
extern NSString* const kPJLinkERR2;
extern NSString* const kPJLinkERR3;
extern NSString* const kPJLinkERR4;
extern NSString* const kPJLinkHeaderClass;
extern NSString* const PJLinkErrorDomain;
extern NSString* const kPJLinkCR;

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
