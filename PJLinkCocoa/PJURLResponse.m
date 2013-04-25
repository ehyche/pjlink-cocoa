//
//  PJURLResponse.m
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "PJURLResponse.h"

@interface PJURLResponse()
{
    NSArray* _responses;
}

@end

@implementation PJURLResponse

@synthesize responses = _responses;

-(id) initWithURL:(NSURL*) url responses:(NSArray*) responses
{
    self = [super initWithURL:url
                     MIMEType:nil
        expectedContentLength:0
             textEncodingName:nil];
    if (self)
    {
        _responses = [NSArray arrayWithArray:responses];
    }

    return self;
}

@end
