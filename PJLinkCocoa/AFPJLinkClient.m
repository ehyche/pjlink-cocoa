//
//  AFPJLinkClient.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "AFPJLinkClient.h"
#import "AFPJLinkRequestOperation.h"

NSTimeInterval const kAFPJLinkClientDefaultTimeout = 30.0;

@interface AFPJLinkClient()

@property(readwrite,nonatomic,strong) NSURLCredential* defaultCredential;

@end

@implementation AFPJLinkClient

- (NSString*) host {
    return [self.baseURL host];
}

- (NSInteger)port {
    return [[self.baseURL port] integerValue];
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (self) {
        // Clear the default headers that AFHTTPClient sets
        [self setDefaultHeader:@"Accept-Language" value:nil];
        [self setDefaultHeader:@"User-Agent" value:nil];
    }

    return self;
}

- (void)makeRequestWithBody:(NSString*)requestBody
                    success:(AFPJLinkSuccessBlock)successBlock
                    failure:(AFPJLinkFailureBlock)failureBlock {
    [self makeRequestWithBody:requestBody
                      timeout:kAFPJLinkClientDefaultTimeout
                      success:successBlock
                      failure:failureBlock];
}

- (void)makeRequestWithBody:(NSString*)requestBody
                    timeout:(NSTimeInterval)requestTimeout
                    success:(AFPJLinkSuccessBlock)successBlock
                    failure:(AFPJLinkFailureBlock)failureBlock {
    // Create the request
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:self.baseURL];
    [request setHTTPBody:[requestBody dataUsingEncoding:NSUTF8StringEncoding]];
    // Set the timeout
    request.timeoutInterval = requestTimeout;
    // Create an AFPJLinkRequestOperation
    AFPJLinkRequestOperation* operation = [[AFPJLinkRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    operation.credential = self.defaultCredential;
    // Enqueue the operation
    [self.operationQueue addOperation:operation];
}

@end
