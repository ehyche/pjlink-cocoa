//
//  PJURLResponse.h
//  PJController
//
//  Created by Eric Hyche on 12/17/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PJURLResponse : NSURLResponse

-(id) initWithURL:(NSURL*) url responses:(NSArray*) responses;

@property(nonatomic,readonly) NSArray* responses; // Array of PJResponseInfo's

@end
