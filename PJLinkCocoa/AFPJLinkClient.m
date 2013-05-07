//
//  AFPJLinkClient.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "AFPJLinkClient.h"
#import "AFPJLinkRequestOperation.h"

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

- (void)makeRequestWithBody:(NSString*) requestBody
                    success:(void (^)(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses)) success
                    failure:(void (^)(AFPJLinkRequestOperation* operation, NSError* error)) failure {
    // Create the request
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:self.baseURL];
    [request setHTTPBody:[requestBody dataUsingEncoding:NSUTF8StringEncoding]];
    // Create an AFPJLinkRequestOperation
    AFPJLinkRequestOperation* operation = [[AFPJLinkRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:success failure:failure];
    operation.credential = self.defaultCredential;
    // Enqueue the operation
    [self.operationQueue addOperation:operation];
}

@end
