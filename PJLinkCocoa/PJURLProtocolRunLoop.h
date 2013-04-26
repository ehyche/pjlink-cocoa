//
//  PJURLProtocolRunLoop.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/25/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

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

@interface PJURLProtocolRunLoop : NSURLProtocol<AsyncSocketDelegate>

@end
