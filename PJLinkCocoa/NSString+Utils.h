//
//  NSString+Utils.h
//  PJController
//
//  Created by Eric Hyche on 2/28/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Utils)

-(NSDictionary*) keysAndValuesSeparatedBy:(NSString*) equalsDelimiter
                         pairsSeparatedBy:(NSString*) pairsDelimiter;

@end
