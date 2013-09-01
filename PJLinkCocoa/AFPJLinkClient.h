//
//  AFPJLinkClient.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"
#import "AFPJLinkRequestOperation.h"

@class AFPJLinkRequestOperation;


@interface AFPJLinkClient : AFHTTPClient

@property(nonatomic,readonly) NSString* host;
@property(nonatomic,readonly) NSInteger port;

- (void)makeRequestWithBody:(NSString*)requestBody
                    success:(AFPJLinkSuccessBlock)successBlock
                    failure:(AFPJLinkFailureBlock)failureBlock;

- (void)makeRequestWithBody:(NSString*)requestBody
                    timeout:(NSTimeInterval)requestTimeout
                    success:(AFPJLinkSuccessBlock)successBlock
                    failure:(AFPJLinkFailureBlock)failureBlock;

@end

