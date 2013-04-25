//
//  NSString+Utils.m
//  PJController
//
//  Created by Eric Hyche on 2/28/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "NSString+Utils.h"

@implementation NSString (Utils)

-(NSDictionary*) keysAndValuesSeparatedBy:(NSString*) equalsDelimiter
                         pairsSeparatedBy:(NSString*) pairsDelimiter
{
    NSMutableDictionary* tmp = [NSMutableDictionary dictionary];

    NSUInteger selfLength = [self length];
    if (selfLength > 0 && [equalsDelimiter length] > 0 && [pairsDelimiter length] > 0)
    {
        // Split up the string by the pairs delimiter
        NSArray* pairs = [self componentsSeparatedByString:pairsDelimiter];
        // Iterate through the name/value pairs
        for (NSString* pair in pairs)
        {
            // Make sure we have a non-zero length
            if ([pair length] > 0)
            {
                // Now split up the string with the equals delimiter
                NSArray* keyValueComponents = [pair componentsSeparatedByString:equalsDelimiter];
                // This could have 1 or 2 components. If it has 1,
                // then we will put [NSNull null] for the value.
                NSUInteger numKeyValueComponents = [keyValueComponents count];
                if (numKeyValueComponents > 0)
                {
                    // Get the key component
                    NSString* key = [keyValueComponents objectAtIndex:0];
                    // We have to have a non-zero length key
                    if ([key length] > 0)
                    {
                        // We have a valid key.
                        // Now we may or may not have a value
                        id value = [NSNull null];
                        if (numKeyValueComponents > 1)
                        {
                            NSString* valueStr = [keyValueComponents objectAtIndex:1];
                            if ([valueStr length] > 0)
                            {
                                value = valueStr;
                            }
                        }
                        // Now set the name/value pair in the temporary dictionary
                        [tmp setObject:value forKey:key];
                    }
                }
            }
        }
    }

    return [NSDictionary dictionaryWithDictionary:tmp];
}

@end
