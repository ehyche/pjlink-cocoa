//
//  NSMutableURLRequest+PJLink.m
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "NSMutableURLRequest+PJLink.h"
#import "PJDefinitions.h"

@implementation NSMutableURLRequest (PJLink)

-(void) setRequestCommands:(NSArray*) commands
{
    [NSURLProtocol setProperty:commands
                        forKey:k_commandsRequestProperty
                     inRequest:self];
}

@end
