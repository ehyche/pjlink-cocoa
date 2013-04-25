//
//  NSURLRequest+PJLink.m
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "NSURLRequest+PJLink.h"
#import "PJDefinitions.h"

@implementation NSURLRequest (PJLink)

-(NSArray*) requestCommands
{
    return [NSURLProtocol propertyForKey:k_commandsRequestProperty inRequest:self];
}

@end
