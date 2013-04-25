//
//  NSURL+Utils.m
//  PJController
//
//  Created by Eric Hyche on 2/28/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "NSURL+Utils.h"
#import "NSString+Utils.h"

@implementation NSURL (Utils)

-(NSDictionary*) queryParameters
{
    // Get the query string
    NSString* query = [self query];
    // Split up the query string into name=value pairs separated by a & delimiter
    NSDictionary* queryParameters = [query keysAndValuesSeparatedBy:@"=" pairsSeparatedBy:@"&"];
    // Create a new dictionary made up of escaped names and values
    NSMutableDictionary* tmp = [NSMutableDictionary dictionaryWithCapacity:[queryParameters count]];
    for (NSString* queryKey in queryParameters)
    {
        NSString* queryValue     = [queryParameters objectForKey:queryKey];
        NSString* unescapedKey   = [queryKey stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString* unescapedValue = [queryValue stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [tmp setObject:unescapedValue forKey:unescapedKey];
    }

    return [NSDictionary dictionaryWithDictionary:tmp];
}

@end
