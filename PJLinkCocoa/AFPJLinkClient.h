//
//  AFPJLinkClient.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"

@class AFPJLinkRequestOperation;

@interface AFPJLinkClient : AFHTTPClient

@property(nonatomic,readonly) NSString* host;
@property(nonatomic,readonly) NSInteger port;

- (void)makeRequestWithBody:(NSString*) requestBody
                    success:(void (^)(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses)) success
                    failure:(void (^)(AFPJLinkRequestOperation* operation, NSError* error)) failure;

@end

